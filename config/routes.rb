Rails.application.routes.draw do
  # Bell notification routes
  get 'bell_notifications/dropdown', to: 'bell_notifications#dropdown', as: 'bell_notifications_dropdown'
  get 'bell_notifications/unread_count', to: 'bell_notifications#unread_count', as: 'bell_notifications_unread_count'
  put 'bell_notifications/:id/mark_read', to: 'bell_notifications#mark_read', as: 'bell_notification_mark_read'
  put 'bell_notifications/mark_all_read', to: 'bell_notifications#mark_all_read', as: 'bell_notifications_mark_all_read'
end
