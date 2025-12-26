require_relative 'redmine_bell_notifications/settings'
require_relative 'redmine_bell_notifications/notification_builder'
require_relative 'redmine_bell_notifications/patches/mailer_patch'
require_relative 'redmine_bell_notifications/view_hooks'

module RedmineBellNotifications
  class << self
    # Setup patches and hooks
    def setup
      # Apply mailer patch to intercept email delivery
      ::Mailer.prepend Patches::MailerPatch

      # Load view hooks
      ViewHooks # just load it

      Rails.logger.info "RedmineBellNotifications: Plugin initialized"
    end

    # Cleanup old notifications (older than specified days)
    # Default: 30 days (1 month)
    # Uses batch processing to avoid locking table for large deletions
    def cleanup_old_notifications(days = 30)
      return 0 unless days.is_a?(Integer) && days > 0

      total_deleted = 0
      batch_size = 1000

      loop do
        deleted = BellNotification.where("created_at < ?", days.days.ago).limit(batch_size).delete_all
        break if deleted == 0

        total_deleted += deleted

        # Small pause to allow other queries to proceed
        sleep 0.1 if deleted == batch_size
      end

      Rails.logger.info "RedmineBellNotifications: Deleted #{total_deleted} notifications older than #{days} days"
      total_deleted
    end

    # Automatic cleanup - runs periodically without affecting performance
    # Checks if cleanup is due and runs it in a non-blocking way
    # FIXED: Uses Rails.application.executor instead of Thread.new for better thread safety
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

          Rails.logger.info "RedmineBellNotifications: Auto-cleanup completed. Deleted #{deleted_count} notifications."
        rescue => e
          Rails.logger.error "RedmineBellNotifications: Auto-cleanup failed: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end
    end

    # Check if cleanup is due (based on cleanup_interval setting)
    def cleanup_due?
      last_cleanup = get_last_cleanup_time
      cleanup_interval = Settings.cleanup_interval_hours

      # If never run, or last run was more than cleanup_interval hours ago
      last_cleanup.nil? || last_cleanup < cleanup_interval.hours.ago
    end

    # Get last cleanup timestamp from cache
    def get_last_cleanup_time
      Rails.cache.read('bell_notifications_last_cleanup')
    rescue => e
      Rails.logger.debug "RedmineBellNotifications: Could not read last cleanup time: #{e.message}"
      nil
    end

    # Update last cleanup timestamp
    def update_last_cleanup_time
      Rails.cache.write('bell_notifications_last_cleanup', Time.current, expires_in: 30.days)
    rescue => e
      Rails.logger.error "RedmineBellNotifications: Could not update last cleanup time: #{e.message}"
    end
  end
end
