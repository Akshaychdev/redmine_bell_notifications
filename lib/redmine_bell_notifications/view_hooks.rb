module RedmineBellNotifications
  class ViewHooks < Redmine::Hook::ViewListener
    # Render CSS and JS in the <head> tag
    render_on :view_layouts_base_html_head,
              partial: 'hooks/bell_notifications/view_layouts_base_html_head'

    # Render bell icon in the body
    # - Desktop: JavaScript moves it to #quick-search (after project switcher)
    # - Mobile: CSS applies fixed positioning (next to hamburger menu)
    render_on :view_layouts_base_body_top,
              partial: 'hooks/bell_notifications/bell_icon'
  end
end
