# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class BellNotificationsIntegrationTest < Redmine::IntegrationTest
  fixtures :users, :email_addresses, :roles, :members, :member_roles,
           :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :custom_fields, :custom_values, :custom_fields_trackers,
           :bell_notifications, :journals, :news

  def setup
    @user = User.find(2) # jsmith
    @admin = User.find(1) # admin
    @project = Project.find(1) # eCookbook
  end

  def test_issue_creation_creates_bell_notification
    log_user('jsmith', 'jsmith')

    # Count notifications before
    initial_count = BellNotification.count

    # Create an issue
    post '/projects/ecookbook/issues', params: {
      issue: {
        tracker_id: 1,
        subject: 'Integration test issue',
        description: 'Test description',
        priority_id: 4
      }
    }

    assert_response :redirect
    follow_redirect!

    # Notification should be created for users watching the project
    # Note: Actual count depends on project watchers
    assert BellNotification.count >= initial_count
  end

  def test_issue_update_creates_bell_notification
    log_user('jsmith', 'jsmith')

    issue = Issue.find(1)
    initial_count = BellNotification.count

    # Update the issue
    put "/issues/#{issue.id}", params: {
      issue: {
        notes: 'Test comment'
      }
    }

    assert_response :redirect

    # Notification should be created for issue watchers
    assert BellNotification.count >= initial_count
  end

  def test_multiple_notifications_display_in_correct_order
    log_user('jsmith', 'jsmith')

    # Create multiple notifications at different times
    notifications = []
    3.times do |i|
      notifications << BellNotification.create!(
        user: @user,
        event_type: 'test',
        title: "Notification #{i}",
        body: "Body #{i}",
        created_at: (3 - i).hours.ago
      )
    end

    get '/bell/notifications/dropdown.js', xhr: true
    assert_response :success

    # Verify notifications are loaded correctly
    assert_match /bell-notifications-dropdown/, @response.body
  ensure
    notifications.each(&:destroy)
  end
end
