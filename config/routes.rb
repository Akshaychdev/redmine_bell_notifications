Rails.application.routes.draw do
  # Bell notification routes - namespaced to avoid conflicts
  # Following Redmine plugin routing conventions
  #
  # Routes generated:
  #   GET  /bell/notifications/dropdown          -> bell_notifications#dropdown
  #   GET  /bell/notifications/unread_count      -> bell_notifications#unread_count
  #   PUT  /bell/notifications/mark_all_read     -> bell_notifications#mark_all_read
  #   PUT  /bell/notifications/:id/mark_read     -> bell_notifications#mark_read
  scope :bell do
    resources :notifications, controller: 'bell_notifications', only: [] do
      collection do
        get :dropdown
        get :unread_count
        put :mark_all_read
      end
      member do
        put :mark_read
      end
    end
  end
end
