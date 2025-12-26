class BellNotificationsController < ApplicationController
  before_action :require_login
  before_action :find_notification, only: [:mark_read]

  # GET /bell_notifications/dropdown
  # Returns dropdown content with latest notifications
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

  # GET /bell_notifications/unread_count
  # Returns JSON with unread notification count
  def unread_count
    count = BellNotification.for_user(User.current).unread.count

    respond_to do |format|
      format.json { render json: { count: count } }
    end
  end

  # PUT /bell_notifications/:id/mark_read
  # Marks a notification as read and redirects to its URL
  def mark_read
    @notification.mark_as_read!

    redirect_url = @notification.notification_url || root_path

    respond_to do |format|
      format.html { redirect_to redirect_url }
      format.json { render json: { success: true, url: redirect_url } }
      format.js { render json: { success: true, url: redirect_url } }
    end
  end

  # PUT /bell_notifications/mark_all_read
  # Marks all unread notifications as read
  def mark_all_read
    BellNotification.for_user(User.current).unread.update_all(read_at: Time.current)

    respond_to do |format|
      format.html { redirect_back fallback_location: root_path }
      format.js { render json: { success: true } }
    end
  end

  private

  def find_notification
    @notification = BellNotification.for_user(User.current).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Get dropdown limit from plugin settings
  def dropdown_limit
    RedmineBellNotifications::Settings.dropdown_limit
  end
end
