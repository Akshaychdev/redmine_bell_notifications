module RedmineBellNotifications
  # Notification Builder - Extracts notification data from email messages
  #
  # This class is responsible for parsing Redmine email notifications and
  # extracting relevant data to create bell notifications. It analyzes email
  # headers, subject, and body to determine the notifiable object, actor,
  # event type, and other metadata.
  #
  # @example Create notifications from an email
  #   builder = NotificationBuilder.new(mail)
  #   notification = builder.create_notification_for(user)
  #
  # @attr_reader [Mail::Message] mail The email message being processed
  # @attr_reader [String] title Extracted notification title from subject
  # @attr_reader [String] body Extracted preview text from email body
  # @attr_reader [ActiveRecord::Base] notifiable The related object (Issue, Journal, etc.)
  # @attr_reader [String] event_type The type of event that triggered the notification
  # @attr_reader [User] actor The user who triggered the event
  # @attr_reader [String] url The URL to the notifiable object
  class NotificationBuilder
    attr_reader :mail, :title, :body, :notifiable, :event_type, :actor, :url

    # Initialize a new NotificationBuilder
    #
    # Immediately extracts all data from the email upon initialization.
    #
    # @param mail [Mail::Message] The email message to process
    def initialize(mail)
      @mail = mail
      @title = extract_title
      @body = extract_body
      @notifiable = extract_notifiable
      @event_type = extract_event_type
      @actor = extract_actor
      @url = extract_url
    end

    # Create a bell notification for a specific user
    #
    # @param user [User] The user to create the notification for
    # @return [BellNotification, nil] The created notification, or nil on error
    def create_notification_for(user)
      # Generate URL during creation to avoid N+1 queries later
      generated_url = @url.presence || UrlGenerator.generate_for(@notifiable)

      BellNotification.create!(
        user: user,
        notifiable: @notifiable,
        event_type: @event_type,
        actor_id: @actor&.id,
        title: @title,
        body: @body,
        url: generated_url
      )
    rescue => e
      RedmineBellNotifications::Logger.error(
        "Failed to create notification",
        exception: e,
        context: { user_id: user.id, event_type: @event_type }
      )
      nil
    end

    private

    # Extract email subject as notification title
    #
    # @return [String] The email subject line, stripped of whitespace
    def extract_title
      @mail.subject.to_s.strip
    end

    # Extract email body preview text
    #
    # Extracts the first 500 characters from the email body, handling both
    # plain text and multipart emails. Removes Redmine's email footer.
    #
    # @return [String] Preview text (max 500 chars), or empty string on error
    def extract_body
      text = if @mail.multipart?
               @mail.text_part&.body&.decoded || @mail.html_part&.body&.decoded || ''
             else
               @mail.body.decoded
             end

      # Strip Redmine email header if present
      text = text.gsub(/^-- ?\n.*\z/m, '') if text
      text.to_s.strip[0...Constants::MAX_BODY_LENGTH]
    rescue => e
      RedmineBellNotifications::Logger.error(
        "Failed to extract email body",
        exception: e
      )
      ''
    end

    # Extract the notifiable object from email headers
    #
    # Attempts to identify the object this notification is about by checking
    # Redmine's custom email headers (X-Redmine-Issue-Id, etc.) or parsing
    # the subject line as a fallback.
    #
    # @return [ActiveRecord::Base, nil] The notifiable object, or nil if not found
    def extract_notifiable
      # Try to extract from Redmine custom headers first
      if issue_id = extract_header('X-Redmine-Issue-Id')
        return Issue.find_by(id: issue_id.to_i)
      end

      if journal_id = extract_header('X-Redmine-Journal-Id')
        return Journal.find_by(id: journal_id.to_i)
      end

      if news_id = extract_header('X-Redmine-News-Id')
        return News.find_by(id: news_id.to_i)
      end

      if wiki_content_id = extract_header('X-Redmine-WikiContent-Id')
        return WikiContent.find_by(id: wiki_content_id.to_i)
      end

      if message_id = extract_header('X-Redmine-Message-Id')
        return Message.find_by(id: message_id.to_i)
      end

      if document_id = extract_header('X-Redmine-Document-Id')
        return Document.find_by(id: document_id.to_i)
      end

      # Fallback: try to parse from subject line
      parse_notifiable_from_subject
    rescue => e
      RedmineBellNotifications::Logger.error(
        "Failed to extract notifiable from mail",
        exception: e
      )
      nil
    end

    # Parse the subject line to find object references
    #
    # Fallback method when headers don't contain notifiable information.
    # Currently only supports issue references (e.g., "#123").
    #
    # @return [Issue, nil] The issue if found, nil otherwise
    def parse_notifiable_from_subject
      subject = @title

      # Try to match issue pattern: "Bug #123:" or "[Project] Bug #123:"
      if subject =~ /#(\d+)/
        Issue.find_by(id: $1.to_i)
      else
        nil
      end
    end

    # Extract or infer the event type
    #
    # First checks for X-Redmine-Event header, then infers from notifiable state.
    #
    # @return [String] Event type (e.g., 'issue_added', 'issue_updated')
    def extract_event_type
      extract_header('X-Redmine-Event') || infer_event_type
    end

    # Infer event type from the notifiable object's state
    #
    # Uses object timestamps and properties to determine if it was just created
    # or is being updated. More reliable than parsing subject lines.
    #
    # @return [String] Inferred event type, or 'unknown' if cannot determine
    def infer_event_type
      return 'unknown' unless @notifiable

      case @notifiable
      when Issue
        # Check if issue was just created by comparing timestamps
        if @notifiable.created_on && @notifiable.updated_on &&
           (@notifiable.updated_on - @notifiable.created_on).abs < Constants::ISSUE_CREATION_THRESHOLD_SECONDS
          'issue_added'
        else
          'issue_updated'
        end
      when Journal
        'issue_updated'
      when News
        'news_added'
      when WikiContent
        # WikiContent doesn't have created_on, check version
        if @notifiable.version && @notifiable.version == 1
          'wiki_content_added'
        else
          'wiki_content_updated'
        end
      when Message
        'message_posted'
      when Document
        'document_added'
      else
        'unknown'
      end
    end

    # Extract the actor (user who triggered the event)
    #
    # Attempts to identify the user who caused this notification by checking:
    # 1. X-Redmine-Sender header
    # 2. Notifiable object's author or last editor
    # 3. Current user as fallback
    #
    # @return [User, nil] The actor user, or nil if cannot be determined
    def extract_actor
      # Priority 1: Extract from X-Redmine-Sender header (contains login, not ID)
      if sender_login = extract_header('X-Redmine-Sender')
        actor = User.find_by(login: sender_login)
        return actor if actor.present?
      end

      # Priority 2: Try to infer from notifiable
      if @notifiable
        actor = case @notifiable
        when Issue
          # For issue updates, check if there's a recent journal by someone other than the author
          # This happens when someone updates an issue they didn't create
          recent_journal = @notifiable.journals.order(created_on: :desc).first
          if recent_journal && recent_journal.user_id != @notifiable.author_id
            recent_journal.user
          else
            @notifiable.author
          end
        when Journal
          @notifiable.user
        when News
          @notifiable.author
        when WikiContent
          @notifiable.author
        when Message
          @notifiable.author
        when Document
          nil
        else
          nil
        end

        return actor if actor.present?
      end

      # Priority 3: Fallback to current user (may be Anonymous in mail context)
      User.current.presence
    rescue => e
      RedmineBellNotifications::Logger.error(
        "Failed to extract actor from mail",
        exception: e
      )
      nil
    end

    # Extract URL from mail or generate from notifiable
    # Currently returns nil to let UrlGenerator handle it during creation
    #
    # @return [nil] Always returns nil; URL generation delegated to UrlGenerator
    def extract_url
      # Could extract from email body if needed
      # For now, delegate to UrlGenerator during notification creation
      nil
    end

    # Helper to extract header value safely
    #
    # @param name [String] The header name to extract
    # @return [String, nil] The header value, or nil if not found
    def extract_header(name)
      header = @mail.header[name]
      header&.value
    rescue => e
      RedmineBellNotifications::Logger.debug(
        "Header not found",
        context: { header: name, error: e.message }
      )
      nil
    end
  end
end
