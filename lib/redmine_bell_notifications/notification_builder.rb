module RedmineBellNotifications
  class NotificationBuilder
    attr_reader :mail, :title, :body, :notifiable, :event_type, :actor, :url

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
    def create_notification_for(user)
      # Generate URL during creation to avoid N+1 queries later
      generated_url = @url.presence || generate_url_for_notifiable

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
      Rails.logger.error "BellNotifications: Failed to create notification for user #{user.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end

    private

    # Extract email subject as title
    def extract_title
      @mail.subject.to_s.strip
    end

    # Extract email body preview (first 500 chars)
    def extract_body
      text = if @mail.multipart?
               @mail.text_part&.body&.decoded || @mail.html_part&.body&.decoded || ''
             else
               @mail.body.decoded
             end

      # Strip Redmine email header if present
      text = text.gsub(/^-- ?\n.*\z/m, '') if text
      text.to_s.strip[0...500]
    rescue => e
      Rails.logger.error "BellNotifications: Failed to extract body: #{e.message}"
      ''
    end

    # Extract notifiable object from mail headers or subject
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
      Rails.logger.error "BellNotifications: Failed to extract notifiable: #{e.message}"
      nil
    end

    # Parse subject line to find issue/news/wiki references
    def parse_notifiable_from_subject
      subject = @title

      # Try to match issue pattern: "Bug #123:" or "[Project] Bug #123:"
      if subject =~ /#(\d+)/
        Issue.find_by(id: $1.to_i)
      else
        nil
      end
    end

    # Extract event type from headers or infer from context
    def extract_event_type
      extract_header('X-Redmine-Event') || infer_event_type
    end

    # Infer event type from notifiable state instead of brittle string matching
    def infer_event_type
      return 'unknown' unless @notifiable

      case @notifiable
      when Issue
        # Check if issue was just created by comparing timestamps
        if @notifiable.created_on && @notifiable.updated_on &&
           (@notifiable.updated_on - @notifiable.created_on).abs < 5 # Within 5 seconds
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

    # Extract actor (user who triggered the event)
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
      Rails.logger.error "BellNotifications: Failed to extract actor: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end

    # Extract URL from mail or generate from notifiable
    def extract_url
      # Could extract from email body if needed
      # For now, let the model generate it
      nil
    end

    # Generate URL for notifiable object (called during creation to avoid N+1)
    def generate_url_for_notifiable
      return nil unless @notifiable

      begin
        case @notifiable
        when Issue
          Rails.application.routes.url_helpers.issue_path(@notifiable)
        when Journal
          issue = @notifiable.journalized
          Rails.application.routes.url_helpers.issue_path(
            issue,
            anchor: "change-#{@notifiable.id}"
          )
        when News
          Rails.application.routes.url_helpers.news_path(@notifiable)
        when WikiContent
          Rails.application.routes.url_helpers.project_wiki_page_path(
            @notifiable.page.wiki.project,
            @notifiable.page.title
          )
        when Message
          board = @notifiable.board
          Rails.application.routes.url_helpers.board_message_path(
            board,
            @notifiable
          )
        when Document
          Rails.application.routes.url_helpers.document_path(@notifiable)
        when Comment
          # Comments are polymorphic, link to the commented object
          case @notifiable.commented
          when News
            Rails.application.routes.url_helpers.news_path(@notifiable.commented)
          else
            nil
          end
        else
          nil
        end
      rescue => e
        Rails.logger.error "BellNotifications: Failed to generate URL for #{@notifiable.class}: #{e.message}"
        nil
      end
    end

    # Helper to extract header value safely
    def extract_header(name)
      header = @mail.header[name]
      header&.value
    rescue => e
      Rails.logger.debug "BellNotifications: Header #{name} not found: #{e.message}"
      nil
    end
  end
end
