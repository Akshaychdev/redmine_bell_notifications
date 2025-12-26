# Bell Notifications Controller
#
# Handles AJAX requests for the bell notification dropdown and notification actions.
# All actions require the user to be logged in.
#
# Routes (namespaced under /bell/notifications):
#   GET  /dropdown       - Fetch dropdown HTML with notifications
#   GET  /unread_count   - Get count of unread notifications (JSON)
#   PUT  /:id/mark_read  - Mark a single notification as read
#   PUT  /mark_all_read  - Mark all user's notifications as read
class BellNotificationsController < ApplicationController
  before_action :require_login
  before_action :find_notification, only: [:mark_read]

  # Render the dropdown menu with latest notifications
  #
  # Fetches both unread and read notifications, limited by the dropdown_limit setting.
  # Supports both JS and HTML formats for AJAX requests.
  #
  # @return [String] Partial HTML for the dropdown menu
  # @example GET /bell/notifications/dropdown.js
  def dropdown
    @unread_notifications = BellNotification
                              .for_user(User.current)
                              .unread
                              .includes(:actor, :notifiable)
                              .recent
                              .limit(dropdown_limit)

    @read_notifications = BellNotification
                            .for_user(User.current)
                            .read
                            .includes(:actor, :notifiable)
                            .recent
                            .limit(dropdown_limit)

    respond_to do |format|
      format.js { render partial: 'bell_notifications/dropdown' }
      format.html { render partial: 'bell_notifications/dropdown', layout: false }
    end
  end

  # Get the count of unread notifications for the current user
  #
  # Used for polling to update the bell icon badge without loading full dropdown.
  #
  # @return [JSON] Hash with count key
  # @example GET /bell/notifications/unread_count
  #   { "count": 5 }
  def unread_count
    count = BellNotification.for_user(User.current).unread.count

    respond_to do |format|
      format.json { render json: { count: count } }
    end
  end

  # Mark a single notification as read
  #
  # Marks the notification as read by setting read_at timestamp.
  # Returns success status and the notification URL.
  #
  # @return [JSON,HTML] Success status and redirect URL
  # @example PUT /bell/notifications/123/mark_read
  #   { "success": true, "url": "/issues/123" }
  def mark_read
    @notification.mark_as_read!

    redirect_url = @notification.notification_url || root_path

    respond_to do |format|
      format.html { redirect_to redirect_url }
      format.json { render json: { success: true, url: redirect_url } }
      format.js { render json: { success: true, url: redirect_url } }
    end
  end

  # Mark all unread notifications as read for the current user
  #
  # Bulk updates all unread notifications by setting read_at timestamp.
  # Uses update_all for performance (single SQL UPDATE query).
  #
  # @return [JSON,HTML] Success status
  # @example PUT /bell/notifications/mark_all_read
  #   { "success": true }
  def mark_all_read
    BellNotification.for_user(User.current).unread.update_all(read_at: Time.current)

    respond_to do |format|
      format.html { redirect_back fallback_location: root_path }
      format.js { render json: { success: true } }
    end
  end

  private

  # Find and authorize notification access for current user
  #
  # Ensures users can only access their own notifications.
  # Returns 404 if notification doesn't exist or doesn't belong to user.
  #
  # @return [void]
  # @raise [ActiveRecord::RecordNotFound] If notification not found or unauthorized
  def find_notification
    @notification = BellNotification.for_user(User.current).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Get the maximum number of notifications to show in dropdown
  #
  # Reads from plugin settings with fallback to default value.
  #
  # @return [Integer] Number of notifications to display (default: 10)
  def dropdown_limit
    RedmineBellNotifications::Settings.dropdown_limit
  end
end
