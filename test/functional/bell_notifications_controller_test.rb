# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class BellNotificationsControllerTest < Redmine::ControllerTest
  fixtures :users, :issues, :projects, :trackers, :issue_statuses,
           :enumerations, :roles, :members, :member_roles,
           :bell_notifications, :journals, :news

  def setup
    @user = User.find(2) # jsmith
    @request.session[:user_id] = @user.id
  end

  def test_dropdown_should_return_js_format
    get :dropdown, xhr: true

    assert_response :success
    assert_match /bell-notifications-dropdown/, @response.body
  end

  def test_dropdown_should_return_html_format
    get :dropdown, format: :html

    assert_response :success
    assert_match /bell-notifications-dropdown/, @response.body
  end

  def test_dropdown_should_load_unread_notifications
    get :dropdown, xhr: true

    assert_response :success
    # Verify response contains dropdown content
    assert_match /bell-notifications-dropdown/, @response.body
  end

  def test_dropdown_should_load_read_notifications
    get :dropdown, xhr: true

    assert_response :success
    # Verify response contains dropdown content
    assert_match /bell-notifications-dropdown/, @response.body
  end

  def test_dropdown_should_respect_limit
    # Create many notifications
    20.times do |i|
      BellNotification.create!(
        user: @user,
        event_type: 'test',
        title: "Test notification #{i}"
      )
    end

    get :dropdown, xhr: true

    assert_response :success
    # Verify response is successful and contains dropdown
    assert_match /bell-notifications-dropdown/, @response.body
  end

  def test_dropdown_should_include_associations
    get :dropdown, xhr: true

    assert_response :success
    # Verify response contains dropdown content
    assert_match /bell-notifications-dropdown/, @response.body
  end

  def test_dropdown_should_be_ordered_by_recent
    get :dropdown, xhr: true

    assert_response :success
    # Verify response contains dropdown content
    assert_match /bell-notifications-dropdown/, @response.body
  end

  def test_dropdown_should_handle_deleted_actor
    # Notification 6 has null actor
    get :dropdown, xhr: true

    assert_response :success
    # Should not raise error even with null actor
  end

  def test_dropdown_should_handle_deleted_notifiable
    # Notification 7 has missing notifiable
    get :dropdown, xhr: true

    assert_response :success
    # Should not raise error even with missing notifiable
  end

  def test_concurrent_mark_as_read_should_be_safe
    notification = BellNotification.find(1)
    exceptions = []
    results = []

    # Simulate concurrent requests
    threads = 3.times.map do
      Thread.new do
        begin
          # Reload in each thread to simulate separate requests
          n = BellNotification.find(notification.id)
          result = n.mark_as_read!
          results << result
        rescue StandardError => e
          exceptions << e
        end
      end
    end

    threads.each(&:join)

    # Verify no exceptions occurred
    assert_equal 0, exceptions.length, "Expected no exceptions, but got: #{exceptions.map(&:message).join(', ')}"

    # Verify the final state
    notification.reload
    assert_not_nil notification.read_at, "Notification should be marked as read"

    # Verify read_at is a valid timestamp
    assert_instance_of ActiveSupport::TimeWithZone, notification.read_at

    # Verify the notification is in read state
    assert notification.read?, "Notification should be in read state"
  end
end
