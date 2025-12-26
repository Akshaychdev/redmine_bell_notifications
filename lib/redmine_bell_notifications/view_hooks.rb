module RedmineBellNotifications
  class ViewHooks < Redmine::Hook::ViewListener
    render_on :view_layouts_base_html_head,
              partial: 'hooks/bell_notifications/view_layouts_base_html_head'
  end
end
