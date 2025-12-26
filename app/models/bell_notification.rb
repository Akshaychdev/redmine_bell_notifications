class BellNotification < ActiveRecord::Base
  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true
  belongs_to :actor, class_name: 'User', optional: true

  validates :user_id, :title, :event_type, presence: true
  validates :body, length: { maximum: 500 }, allow_blank: true
  validates :title, length: { maximum: 255 }

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user_id: user.id) }

  # Mark notification as read
  def mark_as_read!
    update(read_at: Time.current) unless read?
  end

  # Check if notification is read
  def read?
    read_at.present?
  end

  # Get the URL to navigate to this notification's subject
  def notification_url
    return url if url.present?
    generate_url
  end

  private

  # Generate URL based on notifiable type
  def generate_url
    return nil unless notifiable

    case notifiable
    when Issue
      Rails.application.routes.url_helpers.issue_path(notifiable)
    when Journal
      issue = notifiable.journalized
      Rails.application.routes.url_helpers.issue_path(
        issue,
        anchor: "change-#{notifiable.id}"
      )
    when News
      Rails.application.routes.url_helpers.news_path(notifiable)
    when WikiContent
      Rails.application.routes.url_helpers.project_wiki_page_path(
        notifiable.page.wiki.project,
        notifiable.page.title
      )
    when Message
      board = notifiable.board
      Rails.application.routes.url_helpers.board_message_path(
        board,
        notifiable
      )
    when Document
      Rails.application.routes.url_helpers.document_path(notifiable)
    when Comment
      # Comments are polymorphic, link to the commented object
      case notifiable.commented
      when News
        Rails.application.routes.url_helpers.news_path(notifiable.commented)
      else
        nil
      end
    else
      nil
    end
  rescue NameError => e
    # Handle unknown notifiable_type (e.g., 'UnknownType' that doesn't exist)
    Rails.logger.error "BellNotification: Unknown notifiable_type '#{notifiable_type}': #{e.message}"
    nil
  rescue => e
    # Handle other errors (e.g., routing errors, missing associations)
    notifiable_class_name = notifiable.class.name rescue notifiable_type
    Rails.logger.error "BellNotification: Failed to generate URL for #{notifiable_class_name}: #{e.message}"
    nil
  end
end
