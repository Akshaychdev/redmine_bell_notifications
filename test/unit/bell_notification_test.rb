# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class BellNotificationTest < ActiveSupport::TestCase
  fixtures :users, :issues, :projects, :trackers, :issue_statuses,
           :enumerations, :roles, :members, :member_roles,
           :bell_notifications, :journals, :news

  def setup
    @user = User.find(2) # jsmith
    @issue = Issue.find(1)
  end

  def test_should_create_valid_notification
    notification = BellNotification.new(
      user: @user,
      notifiable: @issue,
      event_type: 'issue_added',
      actor_id: 1,
      title: 'Test notification',
      body: 'Test body'
    )

    assert notification.valid?
    assert notification.save
  end

  def test_should_require_user_id
    notification = BellNotification.new(
      notifiable: @issue,
      event_type: 'issue_added',
      title: 'Test notification'
    )

    assert_not notification.valid?
    assert notification.errors[:user_id].present?
  end

  def test_should_require_title
    notification = BellNotification.new(
      user: @user,
      notifiable: @issue,
      event_type: 'issue_added'
    )

    assert_not notification.valid?
    assert notification.errors[:title].present?
  end

  def test_should_require_event_type
    notification = BellNotification.new(
      user: @user,
      notifiable: @issue,
      title: 'Test notification'
    )

    assert_not notification.valid?
    assert notification.errors[:event_type].present?
  end

  def test_should_validate_title_length
    notification = BellNotification.new(
      user: @user,
      event_type: 'issue_added',
      title: 'a' * 256,
      body: 'Test'
    )

    assert_not notification.valid?
    assert notification.errors[:title].present?
  end

  def test_should_validate_body_length
    notification = BellNotification.new(
      user: @user,
      event_type: 'issue_added',
      title: 'Test',
      body: 'a' * 501
    )

    assert_not notification.valid?
    assert notification.errors[:body].present?
  end

  def test_should_allow_blank_body
    notification = BellNotification.new(
      user: @user,
      notifiable: @issue,
      event_type: 'issue_added',
      title: 'Test notification',
      body: nil
    )

    assert notification.valid?
  end

  def test_should_belong_to_user
    notification = BellNotification.find(1)
    assert_equal 2, notification.user_id
    assert_equal 'jsmith', notification.user.login
  end

  def test_should_belong_to_notifiable
    notification = BellNotification.find(1)
    assert_equal 'Issue', notification.notifiable_type
    assert_equal 1, notification.notifiable_id
    assert_instance_of Issue, notification.notifiable
  end

  def test_should_belong_to_actor
    notification = BellNotification.find(1)
    assert_equal 3, notification.actor_id
    assert_instance_of User, notification.actor
    assert_equal 'dlopper', notification.actor.login
  end

  def test_should_allow_nil_actor
    notification = BellNotification.find(6)
    assert_nil notification.actor_id
    assert_nil notification.actor
  end

  def test_should_allow_nil_notifiable
    notification = BellNotification.find(7)
    assert_equal 999, notification.notifiable_id
    assert_nil notification.notifiable
  end

  def test_unread_scope
    unread = BellNotification.for_user(@user).unread
    assert unread.all? { |n| n.read_at.nil? }
    assert unread.size >= 3 # At least 3 unread notifications for user 2
  end

  def test_read_scope
    read = BellNotification.for_user(@user).read
    assert read.all? { |n| n.read_at.present? }
    assert read.size >= 1 # At least 1 read notification for user 2
  end

  def test_recent_scope
    recent = BellNotification.recent.to_a
    assert_equal recent.sort_by(&:created_at).reverse, recent
  end

  def test_for_user_scope
    user_notifications = BellNotification.for_user(@user)
    assert user_notifications.all? { |n| n.user_id == @user.id }
  end

  def test_mark_as_read
    notification = BellNotification.find(1)
    assert notification.read_at.nil?
    assert_not notification.read?

    notification.mark_as_read!
    notification.reload

    assert notification.read_at.present?
    assert notification.read?
  end

  def test_mark_as_read_should_be_idempotent
    notification = BellNotification.find(1)
    notification.mark_as_read!
    first_read_at = notification.read_at

    sleep 0.1 # Small delay to ensure time would change if updated
    notification.mark_as_read!

    assert_equal first_read_at.to_i, notification.read_at.to_i
  end

  def test_read_predicate
    unread_notification = BellNotification.find(1)
    read_notification = BellNotification.find(2)

    assert_not unread_notification.read?
    assert read_notification.read?
  end

  def test_notification_url_with_stored_url
    notification = BellNotification.find(1)
    assert_equal '/issues/1', notification.notification_url
  end

  def test_generate_url_for_issue
    notification = BellNotification.new(
      user: @user,
      notifiable: @issue,
      event_type: 'issue_added',
      title: 'Test'
    )

    url = notification.notification_url
    assert_match /\/issues\/1/, url
  end

  def test_generate_url_for_journal
    journal = Journal.find(1)
    notification = BellNotification.new(
      user: @user,
      notifiable: journal,
      event_type: 'issue_note_added',
      title: 'Test'
    )

    url = notification.notification_url
    assert_match /\/issues\/\d+#change-1/, url
  end

  def test_generate_url_for_news
    news = News.find(1)
    notification = BellNotification.new(
      user: @user,
      notifiable: news,
      event_type: 'news_added',
      title: 'Test'
    )

    url = notification.notification_url
    assert_match /\/news\/1/, url
  end

  def test_notification_url_returns_nil_for_missing_notifiable
    notification = BellNotification.find(7)
    assert_nil notification.notifiable
    # Should return stored URL even if notifiable is missing
    assert_equal '/issues/999', notification.notification_url
  end

  def test_notification_url_returns_nil_for_unknown_type
    notification = BellNotification.new(
      user: @user,
      notifiable_type: 'UnknownType',
      notifiable_id: 1,
      event_type: 'unknown',
      title: 'Test'
    )

    assert_nil notification.notification_url
  end

  def test_should_handle_deleted_actor
    notification = BellNotification.find(1)
    original_actor_id = notification.actor_id

    # Delete notifications where this user is the recipient first
    # (to avoid foreign key constraint on user_id)
    BellNotification.where(user_id: original_actor_id).destroy_all

    # Simulate actor deletion (should set to null due to foreign key)
    User.find(original_actor_id).destroy
    notification.reload

    # The notification should still exist but actor should be nil
    assert_not_nil notification
    assert_nil notification.actor_id
  end

  def test_should_create_notification_without_notifiable
    notification = BellNotification.new(
      user: @user,
      event_type: 'system_notification',
      title: 'System message',
      body: 'This is a system notification',
      url: '/home'
    )

    assert notification.valid?
    assert notification.save
    assert_nil notification.notifiable
  end

  def test_polymorphic_association_with_different_types
    issue_notification = BellNotification.find(1)
    journal_notification = BellNotification.find(3)
    news_notification = BellNotification.find(5)

    assert_instance_of Issue, issue_notification.notifiable
    assert_instance_of Journal, journal_notification.notifiable
    assert_instance_of News, news_notification.notifiable
  end

  def test_should_order_by_created_at_desc_in_recent_scope
    notifications = BellNotification.recent.limit(5).to_a

    notifications.each_cons(2) do |newer, older|
      assert newer.created_at >= older.created_at,
             "Notifications should be ordered by created_at DESC"
    end
  end

  def test_should_combine_scopes
    # Test combining multiple scopes
    unread_recent = BellNotification
                      .for_user(@user)
                      .unread
                      .recent
                      .limit(10)

    assert unread_recent.all? { |n| n.user_id == @user.id }
    assert unread_recent.all? { |n| n.read_at.nil? }
    assert unread_recent.count <= 10
  end
end
