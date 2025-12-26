require File.expand_path('../lib/redmine_bell_notifications', __FILE__)

Redmine::Plugin.register :redmine_bell_notifications do
  name 'Redmine Bell Notifications'
  author 'Linways'
  description 'In-app notification system with bell icon and dropdown. Follows email notification preferences.'
  version '1.0.0'
  url 'https://github.com/linways/redmine_bell_notifications'
  author_url 'https://linways.com'

  requires_redmine version_or_higher: '6.0.0'

  # Plugin settings
  settings default: {
    'retention_days' => 180,     # Keep notifications for 6 months
    'dropdown_limit' => 10,      # Number of notifications to show in dropdown
    'cleanup_interval' => 24     # Run cleanup every 24 hours
  }, partial: 'settings/bell_notifications'

  # Add bell icon to account menu (first item)
  menu :account_menu, :bell_notifications,
       { controller: 'bell_notifications', action: 'dropdown' },
       caption: '<span class="bell-icon-container"></span>'.html_safe,
       html: {
         id: 'bell-notifications-menu',
         class: 'bell-icon-link'
       },
       first: true,
       if: ->(*_) { User.current.logged? }
end

# Initialize the plugin
if Rails.version > '6.0' && Rails.autoloaders.zeitwerk_enabled?
  Rails.application.config.after_initialize do
    RedmineBellNotifications.setup
  end
else
  ActiveSupport::Reloader.to_prepare do
    RedmineBellNotifications.setup
  end
end
