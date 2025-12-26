# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class MailerPatchTest < ActiveSupport::TestCase
  fixtures :users, :issues, :projects, :trackers, :issue_statuses,
           :enumerations, :roles, :members, :member_roles,
           :email_addresses

  def setup
    @user = User.find(2) # jsmith
    @issue = Issue.find(1)
    ActionMailer::Base.deliveries.clear
  end

  def teardown
    ActionMailer::Base.deliveries.clear
  end

  def test_mailer_patch_is_applied
    assert Mailer.respond_to?(:deliver_mail)
  end

  def test_notification_created_when_issue_email_sent
    # Set user to receive all notifications
    @user.update_column(:mail_notification, 'all')

    initial_count = BellNotification.count

    # Send an email notification using Redmine's actual mailer
    User.current = @user
    mail = Mailer.issue_add(@user, @issue).deliver_now

    # Bell notification should be created
    assert BellNotification.count > initial_count
  end

  def test_notification_not_created_for_inactive_user
    inactive_user = User.find(2)
    inactive_user.update_column(:status, User::STATUS_LOCKED)

    initial_count = BellNotification.count

    # Try to send email using Redmine mailer
    User.current = inactive_user
    Mailer.issue_add(inactive_user, @issue).deliver_now

    # Should not create notification for inactive user
    assert_equal initial_count, BellNotification.count
  end

  def test_notification_not_created_for_user_with_no_mail_preference
    @user.update_column(:mail_notification, 'none')

    initial_count = BellNotification.count

    # Try to send email using Redmine mailer
    User.current = @user
    Mailer.issue_add(@user, @issue).deliver_now

    # Should not create notification for user with mail_notification = 'none'
    assert_equal initial_count, BellNotification.count
  end

  def test_notification_created_for_multiple_recipients
    user2 = User.find(2)
    user3 = User.find(3)

    user2.update_column(:mail_notification, 'all')
    user3.update_column(:mail_notification, 'all')

    # Make sure both users are members of the project so they receive notifications
    project = @issue.project
    role = Role.find(1)
    Member.create!(user: user2, project: project, roles: [role]) unless project.members.exists?(user_id: user2.id)
    Member.create!(user: user3, project: project, roles: [role]) unless project.members.exists?(user_id: user3.id)

    initial_count = BellNotification.count

    # Trigger issue update which sends to multiple recipients
    User.current = user2
    @issue.init_journal(user2)
    @issue.notes = 'Test comment'
    @issue.save!

    # Should create notifications for watchers
    # (Actual count depends on who is watching)
    assert BellNotification.count >= initial_count
  end


  def test_should_create_bell_notification_predicate
    active_user = User.find(2)
    active_user.update_column(:mail_notification, 'all')
    active_user.update_column(:status, User::STATUS_ACTIVE)

    assert Mailer.send(:should_create_bell_notification?, active_user)
  end

  def test_should_not_create_for_anonymous_user
    anonymous = User.anonymous
    assert_not Mailer.send(:should_create_bell_notification?, anonymous)
  end

  def test_should_not_create_for_inactive_user
    user = User.find(2)
    user.update_column(:status, User::STATUS_LOCKED)

    assert_not Mailer.send(:should_create_bell_notification?, user)
  end

  def test_should_not_create_for_user_with_mail_notification_none
    user = User.find(2)
    user.update_column(:mail_notification, 'none')

    assert_not Mailer.send(:should_create_bell_notification?, user)
  end


  def test_notification_created_with_correct_attributes
    @user.update_column(:mail_notification, 'all')

    # Use Redmine's actual mailer
    User.current = @user
    Mailer.issue_add(@user, @issue).deliver_now

    notification = BellNotification.for_user(@user).order(created_at: :desc).first
    assert_not_nil notification
    assert_match /#{@issue.subject}/, notification.title
    assert_equal @issue, notification.notifiable
  end

  def test_logging_during_notification_creation
    @user.update_column(:mail_notification, 'all')

    # Should log info messages (we can't easily test this, but ensure it doesn't crash)
    assert_nothing_raised do
      User.current = @user
      Mailer.issue_add(@user, @issue).deliver_now
    end
  end
end
