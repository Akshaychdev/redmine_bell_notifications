require_relative 'redmine_bell_notifications/constants'
require_relative 'redmine_bell_notifications/logger'
require_relative 'redmine_bell_notifications/settings'
require_relative 'redmine_bell_notifications/url_generator'
require_relative 'redmine_bell_notifications/notification_builder'
require_relative 'redmine_bell_notifications/patches/mailer_patch'
require_relative 'redmine_bell_notifications/view_hooks'

module RedmineBellNotifications
  class << self
    # Initialize the plugin by applying patches and loading hooks
    #
    # Called during Rails initialization to set up:
    # - Mailer patch for email interception
    # - View hooks for bell icon rendering
    #
    # @return [void]
    def setup
      # Apply mailer patch to intercept email delivery
      ::Mailer.prepend Patches::MailerPatch

      # Load view hooks
      ViewHooks # just load it

      Logger.info("Plugin initialized successfully")
    end

    # Clean up old notifications from the database
    #
    # Deletes notifications older than the specified number of days.
    # Uses batch processing (1000 records at a time) to avoid long table locks
    # and prevent memory issues with large deletions.
    #
    # @param days [Integer] Number of days to retain (default: 30)
    # @return [Integer] Total number of notifications deleted
    # @example
    #   RedmineBellNotifications.cleanup_old_notifications(90)
    #   # => 1234
    def cleanup_old_notifications(days = 30)
      return 0 unless days.is_a?(Integer) && days > 0

      total_deleted = 0

      loop do
        deleted = BellNotification
          .where("created_at < ?", days.days.ago)
          .limit(Constants::CLEANUP_BATCH_SIZE)
          .delete_all
        break if deleted == 0

        total_deleted += deleted

        # Small pause to allow other queries to proceed
        sleep Constants::CLEANUP_BATCH_PAUSE_SECONDS if deleted == Constants::CLEANUP_BATCH_SIZE
      end

      Logger.info(
        "Cleanup completed",
        context: { deleted: total_deleted, retention_days: days }
      )
      total_deleted
    end

    # Automatically run cleanup if due
    #
    # Checks if enough time has passed since last cleanup (based on cleanup_interval
    # setting) and runs cleanup in a non-blocking way using Rails executor.
    # Safe to call frequently as it checks cleanup_due? first.
    #
    # @return [void]
    # @note Uses Rails.application.executor for thread-safe background execution
    def auto_cleanup
      return unless cleanup_due?

      # Use Rails executor wrapper for thread-safe background execution
      # This is safer than Thread.new as it properly manages the execution context
      Rails.application.executor.wrap do
        begin
          retention_days = Settings.retention_days
          deleted_count = cleanup_old_notifications(retention_days)

          # Update last cleanup timestamp
          update_last_cleanup_time

          Logger.info(
            "Auto-cleanup completed",
            context: { deleted: deleted_count }
          )
        rescue => e
          Logger.error(
            "Auto-cleanup failed",
            exception: e
          )
        end
      end
    end

    # Check if automatic cleanup should run
    #
    # Returns true if cleanup has never run or if cleanup_interval hours
    # have passed since the last run.
    #
    # @return [Boolean] true if cleanup should run, false otherwise
    def cleanup_due?
      last_cleanup = get_last_cleanup_time
      cleanup_interval = Settings.cleanup_interval_hours

      # If never run, or last run was more than cleanup_interval hours ago
      last_cleanup.nil? || last_cleanup < cleanup_interval.hours.ago
    end

    # Get last cleanup timestamp from cache
    #
    # @return [Time, nil] Last cleanup time, or nil if never run or cache error
    def get_last_cleanup_time
      Rails.cache.read('bell_notifications_last_cleanup')
    rescue => e
      Logger.debug(
        "Could not read last cleanup time from cache",
        context: { error: e.message }
      )
      nil
    end

    # Update last cleanup timestamp in cache
    #
    # @return [void]
    def update_last_cleanup_time
      Rails.cache.write(
        'bell_notifications_last_cleanup',
        Time.current,
        expires_in: Constants::CLEANUP_TIMESTAMP_CACHE_EXPIRY_DAYS.days
      )
    rescue => e
      Logger.error(
        "Could not update last cleanup time in cache",
        exception: e
      )
    end
  end
end
