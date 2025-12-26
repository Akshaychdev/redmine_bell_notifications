namespace :redmine do
  namespace :bell_notifications do
    desc 'Cleanup old bell notifications (older than 6 months by default)'
    task cleanup: :environment do
      days = ENV['DAYS']&.to_i || 180  # Default: 6 months (180 days)

      puts "Starting cleanup of bell notifications older than #{days} days..."

      begin
        deleted_count = RedmineBellNotifications.cleanup_old_notifications(days)
        puts "Successfully deleted #{deleted_count} notifications older than #{days} days"
      rescue => e
        puts "Error during cleanup: #{e.message}"
        puts e.backtrace.join("\n")
        exit 1
      end
    end

    desc 'Show bell notification statistics'
    task stats: :environment do
      total = BellNotification.count
      unread = BellNotification.unread.count
      read = BellNotification.read.count

      puts "Bell Notification Statistics:"
      puts "  Total notifications: #{total}"
      puts "  Unread: #{unread}"
      puts "  Read: #{read}"

      if total > 0
        oldest = BellNotification.order(:created_at).first
        newest = BellNotification.order(:created_at).last

        puts "\n  Oldest notification: #{oldest.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
        puts "  Newest notification: #{newest.created_at.strftime('%Y-%m-%d %H:%M:%S')}"

        # Show per-user stats
        user_counts = BellNotification.group(:user_id).count.sort_by { |_, count| -count }.first(5)
        puts "\n  Top 5 users by notification count:"
        user_counts.each do |user_id, count|
          user = User.find_by(id: user_id)
          puts "    #{user&.name || 'Unknown'}: #{count}"
        end
      end
    end
  end
end
