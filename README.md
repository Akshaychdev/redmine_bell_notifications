# Redmine Bell Notifications

An in-app notification system for Redmine 6+ that adds a bell icon to the header with a dropdown showing recent notifications. Notifications follow the same rules and preferences as email notifications.

## Features

- **Bell icon** in the header with unread count badge
- **Dropdown** showing latest unread notifications (configurable: 5-50)
- **Auto-updates** badge count every 60 seconds
- **Click notification** to navigate to the issue/object and mark as read
- **Mark all as read** functionality
- **Follows email notification preferences** - respects user's notification settings
- **Fully theme-compatible** - uses Redmine's native CSS classes and color scheme
  - Works seamlessly with all Redmine themes (classic, alternate, PurpleMine, etc.)
  - Automatically adapts to theme changes
  - No custom colors that clash with themes
- **Independent of email configuration** - works even when email is disabled
- **Automatic data management** - configurable retention period (30-365 days)
- **Mobile-responsive** design

## Requirements

- Redmine 6.0 or higher
- PostgreSQL, MySQL, or SQLite database
- Ruby 3.0 or higher
- Rails 6.1 or higher

## Installation

**IMPORTANT**: The plugin directory must be named exactly `redmine_bell_notifications` to match the plugin registration. Do not rename it.

### 1. Install the Plugin

**For standard Redmine installation:**

```bash
cd /path/to/redmine/plugins
git clone https://github.com/linways/redmine_bell_notifications.git
```

Or download and extract to `plugins/redmine_bell_notifications/`

**For Docker deployment:**

```bash
# Copy plugin to container (ensure directory is named redmine_bell_notifications)
docker cp /path/to/redmine_bell_notifications <container_name>:/usr/src/redmine/plugins/redmine_bell_notifications

# Fix permissions
docker exec <container_name> chown -R redmine:redmine /usr/src/redmine/plugins/redmine_bell_notifications
```

### 2. Run Database Migration

**For standard installation:**

```bash
cd /path/to/redmine
rake redmine:plugins:migrate RAILS_ENV=production
```

**For Docker deployment:**

```bash
docker exec <container_name> bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

### 3. Restart Redmine

```bash
# If using Passenger
touch tmp/restart.txt

# If using systemd
sudo systemctl restart redmine

# If using Docker
docker restart <container_name>
```

### 4. Configure Settings (Optional)

The plugin includes automatic cleanup - no cron job needed! You can configure:

- **Dropdown limit**: Number of notifications to show (5-50)
- **Retention period**: How long to keep notifications (30-365 days)
- **Cleanup interval**: How often to run cleanup (1-168 hours)

Access settings at: **Administration > Plugins > Redmine Bell Notifications > Configure**

## Usage

### For Users

Once installed, logged-in users will see a bell icon (🔔) in the header next to "My account".

**To view notifications:**

1. Click the bell icon
2. A dropdown appears showing your latest unread notifications
3. Click any notification to navigate to the issue/object (marks as read automatically)
4. Click "Mark all as read" to clear all unread notifications

**Notification Badge:**

- Shows the count of unread notifications
- Updates automatically every 60 seconds
- Displays "99+" if you have more than 99 unread notifications

### For Administrators

**Notification Rules:**

- Bell notifications follow the same rules as email notifications
- Users with email notifications set to "none" will NOT receive bell notifications
- Notifications are created for all events that would trigger an email:
  - New issues
  - Issue updates
  - New comments
  - Assignments
  - @mentions
  - Wiki updates
  - News posts
  - Forum messages

**Data Management:**

- The plugin **automatically cleans up old notifications** - no cron job required!
- Cleanup runs in the background based on your configured interval (default: every 24 hours)
- Deletes notifications older than the retention period (default: 180 days)
- Runs in a separate thread to avoid affecting performance
- Manual cleanup is also available:

  ```bash
  rake redmine:bell_notifications:cleanup RAILS_ENV=production
  ```

**Statistics:**
View notification statistics:

```bash
rake redmine:bell_notifications:stats RAILS_ENV=production
```

## Configuration

The plugin can be configured from **Administration > Plugins > Redmine Bell Notifications > Configure**.

### Available Settings

**Notifications in dropdown** (default: 10)
- Number of notifications to display in the dropdown menu
- Range: 5-50 notifications
- Higher values may affect performance for users with many notifications

**Retention period** (default: 180 days)
- How long to keep notifications before automatic cleanup
- Range: 30-365 days
- Shorter retention periods reduce database size

**Cleanup interval** (default: 24 hours)
- How often the automatic cleanup runs
- Range: 1-168 hours (1 hour to 1 week)
- More frequent cleanup keeps database smaller but uses more resources

### Important Notes

- **Bell notifications work independently of email settings** - Notifications are created even when email delivery is disabled or not configured
- Users with email notification preference set to "none" will still NOT receive bell notifications (respects user privacy preferences)
- Changes to settings take effect immediately

## Architecture

### How It Works

1. **Mailer Interception**: The plugin patches Redmine's `Mailer.deliver_mail` method
2. **Notification Creation**: The plugin creates a `BellNotification` record for each recipient whenever Redmine prepares to send an email
3. **Independent Operation**: Bell notifications are created **regardless of email delivery settings** - they work even when:
   - Email credentials are not configured
   - Email delivery is disabled in Redmine settings
   - SMTP server is unavailable
4. **No Impact on Emails**: Email delivery continues normally (if configured) - the plugin only adds in-app notifications
5. **Data Extraction**: Notification data is extracted from the email object:
   - Subject becomes the title
   - Body becomes the preview text
   - Mail headers identify the related issue/object
   - Recipients determine who gets notifications

### Database Schema

Table: `bell_notifications`

- `user_id` - Recipient of the notification
- `notifiable_id`, `notifiable_type` - Polymorphic reference to Issue, Journal, News, etc.
- `event_type` - Type of event (issue_added, issue_updated, etc.)
- `actor_id` - User who triggered the event
- `title` - Notification title (email subject)
- `body` - Preview text (first 500 chars of email)
- `url` - Deep link to the object
- `read_at` - When marked as read (NULL = unread)
- `created_at`, `updated_at` - Timestamps

**Indices:**

- `(user_id, read_at, created_at)` - Fast unread queries
- `(notifiable_type, notifiable_id)` - Polymorphic lookups
- `created_at` - Cleanup queries

## Maintenance

### Automatic Cleanup (Built-in)

The plugin automatically cleans up old notifications **without requiring a cron job**:

- **Runs automatically** in the background when notifications are created
- **Configurable interval** - set how often cleanup runs (default: 24 hours)
- **Configurable retention** - set how long to keep notifications (default: 180 days)
- **Non-blocking** - runs in a separate thread, doesn't affect performance
- **Efficient** - uses database indices for fast deletion

**How it works:**
1. Every time a notification is created, the plugin checks if cleanup is due
2. If the cleanup interval has passed, it triggers cleanup in a background thread
3. Old notifications are deleted based on the retention period
4. The cleanup timestamp is updated in Rails cache

### Manual Cleanup (Optional)

You can also manually trigger cleanup:

```bash
rake redmine:bell_notifications:cleanup RAILS_ENV=production
```

**Custom retention period:**

```bash
# Delete notifications older than 90 days
DAYS=90 rake redmine:bell_notifications:cleanup RAILS_ENV=production
```

**Note:** Manual cleanup is optional - the plugin handles cleanup automatically!

### View Statistics

```bash
rake redmine:bell_notifications:stats RAILS_ENV=production
```

Shows:

- Total notification count
- Read vs unread count
- Oldest and newest notifications
- Top 5 users by notification count

## Troubleshooting

### Bell icon not appearing

1. Clear browser cache and hard reload (Ctrl+F5)
2. Check that you're logged in (bell only shows for logged-in users)
3. Check browser console for JavaScript errors
4. Verify plugin is installed: `ls plugins/redmine_bell_notifications`
5. Restart Redmine after installation

### Notifications not appearing

1. Bell notifications work independently of email - they're created even when email is disabled
2. Verify user's email notification setting is NOT set to "none" (respects user privacy)
3. Check Rails logs: `tail -f log/production.log`
4. Look for errors in the BellNotifications namespace
5. Verify the plugin migration has been run: `rake redmine:plugins:migrate RAILS_ENV=production`

### Dropdown not opening

1. Check browser console for JavaScript errors
2. Verify assets are loaded: View page source and search for `bell_notifications.js`
3. Try disabling other plugins temporarily to check for conflicts

### Performance issues

1. Run cleanup task to reduce table size
2. Check database indices are created:

   ```sql
   SHOW INDEX FROM bell_notifications;
   ```

3. Consider reducing retention period if table is very large

## Uninstallation

### 1. Rollback Database Migration

```bash
cd /path/to/redmine
rake redmine:plugins:migrate NAME=redmine_bell_notifications VERSION=0 RAILS_ENV=production
```

### 2. Remove Plugin Directory

```bash
rm -rf plugins/redmine_bell_notifications
```

### 3. Restart Redmine

```bash
touch tmp/restart.txt
# or restart your application server
```

## Development

### Running Tests

```bash
cd /path/to/redmine
rake redmine:plugins:test NAME=redmine_bell_notifications
```

### File Structure

```
redmine_bell_notifications/
├── init.rb                          # Plugin registration
├── app/
│   ├── controllers/                 # Controllers
│   ├── models/                      # Models
│   └── views/                       # Views
├── assets/                          # JS, CSS, images
├── config/                          # Routes, locales
├── db/migrate/                      # Migrations
├── lib/                             # Core logic, patches
└── test/                            # Tests
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This plugin is licensed under the MIT License.

## Support

For issues, feature requests, or questions:

- GitHub Issues: <https://github.com/linways/redmine_bell_notifications/issues>
- Email: <support@linways.com>

## Credits

Developed by [Linways](https://linways.com)

## Changelog

### Version 1.0.0 (2025-12-26)

- Initial release
- Bell icon with unread count badge
- Dropdown with latest 10 notifications
- Auto-update every 60 seconds
- Mark as read functionality
- Mark all as read functionality
- Automatic cleanup task (6-month retention)
- Theme-compatible design
- Mobile-responsive layout

## Theme Compatibility

The plugin is designed to seamlessly integrate with Redmine's theming system:

### Design Philosophy

- **Uses Redmine's native CSS classes** - The dropdown uses `.drdn-content` and `.drdn-items` classes
- **Follows Redmine's color scheme** - Link colors (#169), hover states (#c61a1a), backgrounds (#f9fafb)
- **Inherits theme fonts** - Uses `var(--fonts-main)` for consistent typography
- **Matches Redmine's UI patterns** - Border colors, shadows, and spacing match Redmine's design

### Tested Themes

The plugin works with:
- **Classic** (default Redmine theme)
- **Alternate** (Redmine's alternate theme)
- **PurpleMine** and other popular community themes
- **Dark themes** (automatically inherits dark color schemes)

### How It Works

The plugin doesn't override theme styles - it inherits them. When you switch themes in Redmine, the bell notification dropdown automatically adapts to match the new theme's colors and styling.

## Roadmap

Future enhancements may include:

- Full notification page (in addition to dropdown)
- Real-time updates via WebSockets/ActionCable
- Per-event notification preferences
- Search and filtering
- Sound/desktop notifications
- Notification archiving
- Export to CSV/JSON
- Mobile app API
