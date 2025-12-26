module RedmineBellNotifications
  # Service class for generating URLs for notifiable objects
  # Centralizes URL generation logic to avoid duplication between
  # BellNotification model and NotificationBuilder
  #
  # @example Generate URL for an issue
  #   UrlGenerator.generate_for(issue)
  #   # => "/issues/123"
  #
  # @example Generate URL for a journal with anchor
  #   UrlGenerator.generate_for(journal)
  #   # => "/issues/123#change-456"
  class UrlGenerator
    # Generate URL for a given notifiable object
    #
    # @param notifiable [ActiveRecord::Base, nil] The object to generate URL for
    #   Supported types: Issue, Journal, News, WikiContent, Message, Document, Comment
    # @return [String, nil] Generated URL path, or nil if notifiable is nil or unsupported
    #
    # @example
    #   UrlGenerator.generate_for(Issue.find(1))
    #   # => "/issues/1"
    def self.generate_for(notifiable)
      return nil unless notifiable

      begin
        case notifiable
        when Issue
          Rails.application.routes.url_helpers.issue_path(notifiable)
        when Journal
          generate_journal_url(notifiable)
        when News
          Rails.application.routes.url_helpers.news_path(notifiable)
        when WikiContent
          generate_wiki_content_url(notifiable)
        when Message
          generate_message_url(notifiable)
        when Document
          Rails.application.routes.url_helpers.document_path(notifiable)
        when Comment
          generate_comment_url(notifiable)
        else
          nil
        end
      rescue NameError => e
        # Handle unknown notifiable_type (e.g., 'UnknownType' that doesn't exist)
        RedmineBellNotifications::Logger.error(
          "Unknown notifiable type",
          exception: e,
          context: { type: notifiable.class.name }
        )
        nil
      rescue => e
        # Handle other errors (e.g., routing errors, missing associations)
        notifiable_class_name = notifiable.class.name rescue 'Unknown'
        RedmineBellNotifications::Logger.error(
          "Failed to generate URL",
          exception: e,
          context: { notifiable_class: notifiable_class_name }
        )
        nil
      end
    end

    private

    # Generate URL for Journal with anchor to specific change
    #
    # @param journal [Journal] The journal object
    # @return [String] URL with anchor
    # @raise [StandardError] If journal has no journalized issue
    def self.generate_journal_url(journal)
      issue = journal.journalized
      Rails.application.routes.url_helpers.issue_path(
        issue,
        anchor: "change-#{journal.id}"
      )
    end

    # Generate URL for WikiContent
    #
    # @param wiki_content [WikiContent] The wiki content object
    # @return [String] URL to wiki page
    # @raise [StandardError] If wiki content has no associated page or project
    def self.generate_wiki_content_url(wiki_content)
      Rails.application.routes.url_helpers.project_wiki_page_path(
        wiki_content.page.wiki.project,
        wiki_content.page.title
      )
    end

    # Generate URL for Message in a board
    #
    # @param message [Message] The message object
    # @return [String] URL to message in board
    # @raise [StandardError] If message has no associated board
    def self.generate_message_url(message)
      board = message.board
      Rails.application.routes.url_helpers.board_message_path(
        board,
        message
      )
    end

    # Generate URL for Comment based on what it's commenting on
    #
    # @param comment [Comment] The comment object
    # @return [String, nil] URL to the commented object, or nil if unsupported
    def self.generate_comment_url(comment)
      # Comments are polymorphic, link to the commented object
      case comment.commented
      when News
        Rails.application.routes.url_helpers.news_path(comment.commented)
      else
        nil
      end
    end
  end
end
