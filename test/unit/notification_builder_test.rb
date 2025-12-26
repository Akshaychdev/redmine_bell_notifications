# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class NotificationBuilderTest < ActiveSupport::TestCase
  fixtures :users, :issues, :projects, :trackers, :issue_statuses,
           :enumerations, :roles, :members, :member_roles,
           :journals, :news

  def setup
    @user = User.find(2) # jsmith
    @issue = Issue.find(1)
  end

  def test_should_extract_title_from_subject
    mail = Mail.new do
      subject 'Test Issue #1: Sample issue'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_equal 'Test Issue #1: Sample issue', builder.title
  end

  def test_should_extract_body_from_text_mail
    mail = Mail.new do
      body 'This is a test notification body'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_equal 'This is a test notification body', builder.body
  end

  def test_should_extract_body_from_multipart_mail
    mail = Mail.new do
      text_part do
        body 'Plain text body'
      end
      html_part do
        content_type 'text/html; charset=UTF-8'
        body '<p>HTML body</p>'
      end
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_equal 'Plain text body', builder.body
  end

  def test_should_truncate_long_body
    long_text = 'a' * 1000
    mail = Mail.new do
      body long_text
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_equal 500, builder.body.length
  end

  def test_should_extract_issue_from_header
    mail = Mail.new do
      subject 'Issue #1'
      headers['X-Redmine-Issue-Id'] = '1'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_instance_of Issue, builder.notifiable
    assert_equal 1, builder.notifiable.id
  end


  def test_should_parse_issue_from_subject
    mail = Mail.new do
      subject 'Bug #1: Sample issue'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_instance_of Issue, builder.notifiable
    assert_equal 1, builder.notifiable.id
  end

  def test_should_return_nil_for_nonexistent_issue
    mail = Mail.new do
      subject 'Bug #99999: Nonexistent issue'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_nil builder.notifiable
  end

  def test_should_infer_issue_added_event_type
    # Create a new issue that was just created
    issue = Issue.new(
      project_id: 1,
      tracker_id: 1,
      subject: 'New issue',
      author_id: 2,
      status_id: 1
    )
    issue.save!

    mail = Mail.new do
      subject "Issue ##{issue.id}"
      headers['X-Redmine-Issue-Id'] = issue.id.to_s
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_equal 'issue_added', builder.event_type
  end

  def test_should_infer_issue_updated_event_type
    # Issue 1 was created more than 5 seconds ago
    mail = Mail.new do
      subject 'Issue #1'
      headers['X-Redmine-Issue-Id'] = '1'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_equal 'issue_updated', builder.event_type
  end


  def test_should_extract_event_type_from_header
    mail = Mail.new do
      subject 'Test'
      headers 'X-Redmine-Event' => 'custom_event'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_equal 'custom_event', builder.event_type
  end

  def test_should_extract_actor_from_sender_header
    mail = Mail.new do
      subject 'Test'
      headers 'X-Redmine-Sender' => 'jsmith'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_kind_of User, builder.actor
    assert_equal 'jsmith', builder.actor.login
  end

  def test_should_extract_actor_from_issue_author
    mail = Mail.new do
      subject 'Issue #1'
      headers['X-Redmine-Issue-Id'] = '1'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_kind_of User, builder.actor
  end


  def test_should_create_notification_for_user
    mail = Mail.new do
      subject 'Test notification'
      body 'Test body'
      headers['X-Redmine-Issue-Id'] = '1'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)

    assert_difference 'BellNotification.count', 1 do
      notification = builder.create_notification_for(@user)
      assert_not_nil notification
      assert_equal @user.id, notification.user_id
      assert_equal 'Test notification', notification.title
    end
  end

  def test_should_generate_url_for_issue
    mail = Mail.new do
      subject 'Issue #1'
      headers['X-Redmine-Issue-Id'] = '1'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    notification = builder.create_notification_for(@user)

    assert_not_nil notification.url
    assert_match /\/issues\/1/, notification.url
  end


  def test_should_handle_missing_notifiable_gracefully
    mail = Mail.new do
      subject 'Issue #99999'
      body 'Nonexistent issue'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)

    # Should still create notification even without notifiable
    notification = builder.create_notification_for(@user)
    assert_not_nil notification
    assert_nil notification.notifiable
  end

  def test_should_handle_multipart_mail_without_text_part
    mail = Mail.new do
      html_part do
        content_type 'text/html; charset=UTF-8'
        body '<p>HTML only body</p>'
      end
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_equal '<p>HTML only body</p>', builder.body
  end

  def test_should_handle_malformed_mail_gracefully
    mail = Mail.new

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_equal '', builder.title
    assert_equal '', builder.body
    assert_nil builder.notifiable
  end


  def test_should_extract_notifiable_priority
    # Test that headers take priority over subject parsing
    mail = Mail.new do
      subject 'Bug #99999: Nonexistent'
      headers 'X-Redmine-Issue-Id' => '1'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_not_nil builder.notifiable, "Notifiable should not be nil"
    assert_equal 1, builder.notifiable.id
  end

  def test_should_strip_redmine_footer_from_body
    body_with_footer = "Main content\n-- \nRedmine footer\nMore footer"

    mail = Mail.new do
      body body_with_footer
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_equal 'Main content', builder.body
  end

  def test_should_handle_empty_subject
    mail = Mail.new do
      subject ''
      body 'Test body'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    assert_equal '', builder.title
  end

  def test_should_handle_nonexistent_sender
    mail = Mail.new do
      subject 'Test'
      headers['X-Redmine-Sender'] = 'nonexistent_user'
    end

    builder = RedmineBellNotifications::NotificationBuilder.new(mail)
    # Should fall back to inferring from notifiable or current user
    # In this case, no notifiable, so should be nil or anonymous
    # Just ensure it doesn't crash
    assert_nothing_raised { builder.actor }
  end
end
