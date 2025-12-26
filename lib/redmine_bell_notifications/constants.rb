module RedmineBellNotifications
  # Constants used throughout the Bell Notifications plugin
  #
  # Centralizes all magic numbers and configuration values to improve
  # maintainability and make the codebase more self-documenting.
  module Constants
    # Notification content limits
    # Maximum length for notification title field
    MAX_TITLE_LENGTH = 255

    # Maximum length for notification body preview
    MAX_BODY_LENGTH = 500

    # Time thresholds
    # Maximum time difference (in seconds) between created_on and updated_on
    # to consider an issue as "just created" vs "updated"
    ISSUE_CREATION_THRESHOLD_SECONDS = 5

    # Cleanup configuration
    # Number of notifications to delete in each batch during cleanup
    # Prevents long table locks on large deletions
    CLEANUP_BATCH_SIZE = 1000

    # Pause duration (in seconds) between cleanup batches
    # Allows other database operations to proceed
    CLEANUP_BATCH_PAUSE_SECONDS = 0.1

    # Retry delay (in milliseconds) after repeated failures
    # Used when automatic cleanup fails multiple times
    CLEANUP_RETRY_DELAY_MS = 300_000 # 5 minutes

    # Cache expiration
    # How long to keep the last cleanup timestamp in cache (in days)
    CLEANUP_TIMESTAMP_CACHE_EXPIRY_DAYS = 30

    # Frontend polling configuration (JavaScript)
    # Default interval for polling unread count (in milliseconds)
    DEFAULT_POLL_INTERVAL_MS = 60_000 # 1 minute

    # Debounce delay for window resize events (in milliseconds)
    RESIZE_DEBOUNCE_MS = 250

    # Maximum number of consecutive polling failures before stopping
    MAX_POLLING_FAILURES = 3

    # Delay before retrying after max failures (in milliseconds)
    POLLING_RETRY_DELAY_MS = 300_000 # 5 minutes

    # Display limits
    # Maximum number shown in unread badge (shows "99+" if more)
    MAX_BADGE_DISPLAY_COUNT = 99
  end
end
