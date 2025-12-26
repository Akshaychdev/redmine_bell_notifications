module RedmineBellNotifications
  # Centralized logging utilities for consistent error handling
  # Provides standardized methods for logging errors, warnings, and info
  module Logger
    class << self
      # Log an error with consistent formatting
      #
      # @param message [String] The error message to log
      # @param exception [Exception, nil] Optional exception object for backtrace
      # @param context [Hash] Optional context information (user_id, notification_id, etc.)
      #
      # @example Log a simple error
      #   Logger.error("Failed to create notification")
      #
      # @example Log error with exception
      #   Logger.error("Database error", exception: e, context: { user_id: 123 })
      def error(message, exception: nil, context: {})
        full_message = build_log_message("ERROR", message, context)
        Rails.logger.error full_message

        if exception
          Rails.logger.error "  Exception: #{exception.class.name} - #{exception.message}"
          if Rails.env.development? || Rails.env.test?
            Rails.logger.error "  Backtrace:\n    #{exception.backtrace.join("\n    ")}"
          else
            # In production, only log first 5 lines of backtrace
            Rails.logger.error "  Backtrace:\n    #{exception.backtrace.first(5).join("\n    ")}"
          end
        end
      end

      # Log a warning with consistent formatting
      #
      # @param message [String] The warning message to log
      # @param context [Hash] Optional context information
      #
      # @example
      #   Logger.warn("No user found for email", context: { email: "user@example.com" })
      def warn(message, context: {})
        full_message = build_log_message("WARN", message, context)
        Rails.logger.warn full_message
      end

      # Log an informational message with consistent formatting
      #
      # @param message [String] The info message to log
      # @param context [Hash] Optional context information
      #
      # @example
      #   Logger.info("Notification created", context: { notification_id: 123, user_id: 45 })
      def info(message, context: {})
        full_message = build_log_message("INFO", message, context)
        Rails.logger.info full_message
      end

      # Log a debug message (only in development/test)
      #
      # @param message [String] The debug message to log
      # @param context [Hash] Optional context information
      def debug(message, context: {})
        return unless Rails.env.development? || Rails.env.test?

        full_message = build_log_message("DEBUG", message, context)
        Rails.logger.debug full_message
      end

      private

      # Build a formatted log message with context
      #
      # @param level [String] Log level (ERROR, WARN, INFO, DEBUG)
      # @param message [String] The main message
      # @param context [Hash] Context information to include
      # @return [String] Formatted log message
      def build_log_message(level, message, context)
        base = "BellNotifications [#{level}]: #{message}"

        if context.any?
          context_str = context.map { |k, v| "#{k}=#{v.inspect}" }.join(", ")
          "#{base} | #{context_str}"
        else
          base
        end
      end
    end
  end
end
