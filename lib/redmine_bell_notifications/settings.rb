module RedmineBellNotifications
  # Centralized settings access module
  # Reduces code duplication and provides consistent defaults
  module Settings
    class << self
      # Get retention period in days
      # Default: 30 days (1 month)
      # Range: 30-365 days
      def retention_days
        value = Setting.plugin_redmine_bell_notifications['retention_days']&.to_i
        value && value > 0 ? value : 30
      end

      # Get number of notifications to show in dropdown
      # Default: 10
      # Range: 5-50
      def dropdown_limit
        value = Setting.plugin_redmine_bell_notifications['dropdown_limit']&.to_i
        value && value > 0 ? value : 10
      end

      # Get cleanup interval in hours
      # Default: 24 hours (daily)
      # Range: 1-168 hours
      # Ensures minimum of 1 hour
      def cleanup_interval_hours
        value = Setting.plugin_redmine_bell_notifications['cleanup_interval']&.to_i
        value && value > 0 ? [value, 1].max : 24
      end
    end
  end
end
