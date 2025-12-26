# Bell Notification model
#
# Represents an in-app notification for a user. Notifications are created when
# emails are sent through Redmine's mailer system and stored in the database
# for display in the bell icon dropdown.
#
# @attr [Integer] user_id The ID of the user who receives this notification
# @attr [Integer] notifiable_id The ID of the related object (Issue, Journal, etc.)
# @attr [String] notifiable_type The class name of the related object
# @attr [String] event_type The type of event (issue_added, issue_updated, etc.)
# @attr [Integer] actor_id The ID of the user who triggered the notification
# @attr [String] title The notification title (max 255 chars)
# @attr [String] body Preview text from the notification (max 500 chars)
# @attr [String] url Direct link to the notifiable object
# @attr [DateTime] read_at Timestamp when the notification was marked as read
# @attr [DateTime] created_at When the notification was created
# @attr [DateTime] updated_at When the notification was last updated
class BellNotification < ActiveRecord::Base
  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true
  belongs_to :actor, class_name: 'User', optional: true

  validates :user_id, :title, :event_type, presence: true
  validates :body, length: { maximum: RedmineBellNotifications::Constants::MAX_BODY_LENGTH }, allow_blank: true
  validates :title, length: { maximum: RedmineBellNotifications::Constants::MAX_TITLE_LENGTH }

  # @!scope class
  # @return [ActiveRecord::Relation] Notifications that have not been read
  scope :unread, -> { where(read_at: nil) }

  # @!scope class
  # @return [ActiveRecord::Relation] Notifications that have been read
  scope :read, -> { where.not(read_at: nil) }

  # @!scope class
  # @return [ActiveRecord::Relation] Notifications ordered by most recent first
  scope :recent, -> { order(created_at: :desc) }

  # @!scope class
  # @param user [User] The user to filter notifications for
  # @return [ActiveRecord::Relation] Notifications belonging to the specified user
  scope :for_user, ->(user) { where(user_id: user.id) }

  # Mark this notification as read
  # Sets the read_at timestamp to the current time if not already read
  #
  # @return [Boolean] true if the notification was marked as read, false if already read
  def mark_as_read!
    update(read_at: Time.current) unless read?
  end

  # Check if this notification has been read
  #
  # @return [Boolean] true if read_at is present, false otherwise
  def read?
    read_at.present?
  end

  # Get the URL to navigate to this notification's subject
  #
  # @return [String, nil] URL path to the notifiable object, or nil if unavailable
  def notification_url
    return url if url.present?

    begin
      RedmineBellNotifications::UrlGenerator.generate_for(notifiable)
    rescue NameError => e
      # Handle case where notifiable_type is invalid (e.g., 'UnknownType')
      Rails.logger.warn("Invalid notifiable_type '#{notifiable_type}' for notification #{id}: #{e.message}")
      nil
    end
  end
end
