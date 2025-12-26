(function() {
  'use strict';

  var BellNotifications = {
    pollInterval: 60000, // Poll every 60 seconds
    pollingIntervalId: null, // Store interval ID to prevent memory leaks
    dropdownOpen: false,
    failureCount: 0, // Track consecutive failures
    maxFailures: 3, // Stop polling after this many failures
    backoffMultiplier: 1, // Exponential backoff multiplier
    resizeListenerAdded: false, // Flag to prevent duplicate resize listeners

    init: function() {
      var self = this;

      // Wait for DOM to be ready
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() {
          self.start();
        });
      } else {
        self.start();
      }
    },

    start: function() {
      this.positionBellIcon();
      this.setupResizeListener();
      this.updateUnreadCount();
      this.startPolling();
      this.bindEvents();
    },

    positionBellIcon: function() {
      // Position bell icon based on screen size using Redmine's 899px breakpoint
      //
      // Desktop (>899px):
      //   - Moves icon to #quick-search div (after project jump box)
      //   - Icon appears inline after project switcher in header
      //   - Dropdown positioned absolutely below the icon
      //
      // Mobile (<=899px):
      //   - Keeps icon in original DOM position (view_layouts_base_body_top hook)
      //   - CSS applies fixed positioning next to hamburger menu
      //   - Dropdown spans full width below fixed header

      var bellWrapper = document.getElementById('bell-notifications-wrapper');
      if (!bellWrapper) {
        console.warn('BellNotifications: Could not find bell wrapper');
        return;
      }

      // Check if we're on mobile (same breakpoint as Redmine's responsive.css)
      var isMobile = window.innerWidth <= 899;

      if (isMobile) {
        // Mobile: Keep wrapper in its original DOM position
        // CSS (media query) handles fixed positioning at top-right next to hamburger menu
      } else {
        // Desktop: Move to quick-search area in header
        var quickSearch = document.getElementById('quick-search');
        if (quickSearch) {
          // Append bell icon after the project jump box in quick-search
          quickSearch.appendChild(bellWrapper);
        } else {
          console.warn('BellNotifications: Could not find quick-search element');
        }
      }
    },

    setupResizeListener: function() {
      // Set up resize listener only once to prevent memory leaks
      if (this.resizeListenerAdded) {
        return;
      }

      var self = this;
      var resizeTimer;
      window.addEventListener('resize', function() {
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(function() {
          self.positionBellIcon();
        }, 250);
      });

      this.resizeListenerAdded = true;
    },

    updateUnreadCount: function() {
      var self = this;

      fetch('/bell_notifications/unread_count', {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      .then(function(response) {
        if (!response.ok) {
          throw new Error('HTTP error ' + response.status);
        }
        return response.json();
      })
      .then(function(data) {
        self.renderBadge(data.count);
        // Reset failure count on success
        self.failureCount = 0;
        self.backoffMultiplier = 1;
      })
      .catch(function(error) {
        console.error('BellNotifications: Error fetching unread count:', error);
        self.handleFetchError();
      });
    },

    handleFetchError: function() {
      this.failureCount++;

      if (this.failureCount >= this.maxFailures) {
        console.error('BellNotifications: Too many consecutive failures (' + this.failureCount + '), stopping polling');
        this.stopPolling();

        // Retry after a longer delay (5 minutes)
        var self = this;
        setTimeout(function() {
          self.failureCount = 0;
          self.backoffMultiplier = 1;
          self.startPolling();
        }, 300000); // 5 minutes
      } else {
        // Exponential backoff
        this.backoffMultiplier = Math.pow(2, this.failureCount - 1);
      }
    },

    renderBadge: function(count) {
      var menu = document.getElementById('bell-notifications-menu');
      if (!menu) return;

      var badge = menu.querySelector('.unread-badge');

      // Always show badge, even when count is 0
      if (!badge) {
        badge = document.createElement('span');
        badge.className = 'unread-badge';
        menu.appendChild(badge);
      }

      badge.textContent = count > 99 ? '99+' : count.toString();
      badge.style.display = 'inline-block';

      // Optional: dim the badge when count is 0
      if (count === 0) {
        badge.style.opacity = '0.5';
      } else {
        badge.style.opacity = '1';
      }
    },

    startPolling: function() {
      var self = this;

      // Clear any existing polling to prevent multiple intervals
      if (this.pollingIntervalId) {
        clearInterval(this.pollingIntervalId);
      }

      this.pollingIntervalId = setInterval(function() {
        self.updateUnreadCount();
      }, this.pollInterval);
    },

    stopPolling: function() {
      if (this.pollingIntervalId) {
        clearInterval(this.pollingIntervalId);
        this.pollingIntervalId = null;
      }
    },

    bindEvents: function() {
      var self = this;

      // Mark as read button (without navigation)
      document.addEventListener('click', function(e) {
        var markReadBtn = e.target.closest('.bell-notification-mark-read');
        if (markReadBtn) {
          e.preventDefault();
          e.stopPropagation(); // Prevent notification click event
          self.handleMarkAsReadClick(markReadBtn);
        }
      });

      // Click notification to mark as read and navigate
      document.addEventListener('click', function(e) {
        var notification = e.target.closest('.bell-notification');
        if (notification && !e.target.closest('.bell-notification-mark-read')) {
          e.preventDefault();
          self.handleNotificationClick(notification);
        }
      });

      // Mark all as read
      document.addEventListener('click', function(e) {
        if (e.target.id === 'bell-mark-all-read' || e.target.closest('#bell-mark-all-read')) {
          e.preventDefault();
          self.markAllAsRead();
        }
      });

      // Toggle read section
      document.addEventListener('click', function(e) {
        var readToggle = e.target.closest('#bell-read-toggle');
        if (readToggle) {
          e.preventDefault();
          self.toggleReadSection();
        }
      });

      // Toggle dropdown when clicking bell icon
      document.addEventListener('click', function(e) {
        var bellIcon = e.target.closest('#bell-notifications-menu');
        if (bellIcon) {
          e.preventDefault();
          self.toggleDropdown();
        }
      });

      // Close dropdown when clicking outside
      document.addEventListener('click', function(e) {
        if (self.dropdownOpen &&
            !e.target.closest('#bell-notifications-menu') &&
            !e.target.closest('.bell-notifications-dropdown')) {
          self.closeDropdown();
        }
      });
    },

    handleMarkAsReadClick: function(button) {
      var self = this;
      var notificationId = button.getAttribute('data-notification-id');
      var notification = button.closest('.bell-notification');

      if (!notificationId) {
        console.warn('BellNotifications: No notification ID found');
        return;
      }

      // Mark as read without navigation
      fetch('/bell_notifications/' + notificationId + '/mark_read', {
        method: 'PUT',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': self.getCSRFToken()
        }
      })
      .then(function(response) {
        return response.json();
      })
      .then(function(data) {
        if (data.success && notification) {
          // Move notification to read section instead of removing
          self.moveNotificationToReadSection(notification);
          // Update the unread count
          self.updateUnreadCount();
        }
      })
      .catch(function(error) {
        console.error('BellNotifications: Error marking as read:', error);
      });
    },

    handleNotificationClick: function(notification) {
      var self = this;
      var notificationId = notification.getAttribute('data-notification-id');
      var url = notification.getAttribute('data-url');

      // Check for valid URL
      if (!notificationId || !url || url === '#' || url === '') {
        console.warn('BellNotifications: No valid URL for notification #' + notificationId);
        return;
      }

      // Mark as read
      fetch('/bell_notifications/' + notificationId + '/mark_read', {
        method: 'PUT',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': self.getCSRFToken()
        }
      })
      .then(function(response) {
        return response.json();
      })
      .then(function(data) {
        if (data.success) {
          window.location.href = url;
        }
      })
      .catch(function(error) {
        console.error('BellNotifications: Error marking as read:', error);
        // Navigate anyway
        window.location.href = url;
      });
    },

    markAllAsRead: function() {
      var self = this;
      var button = document.getElementById('bell-mark-all-read');

      if (!button) return;

      // Store original text
      var originalText = button.textContent;

      // Show loading state
      button.textContent = 'Marking...';
      button.style.opacity = '0.6';
      button.style.pointerEvents = 'none';

      fetch('/bell_notifications/mark_all_read', {
        method: 'PUT',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': self.getCSRFToken()
        }
      })
      .then(function(response) {
        return response.json();
      })
      .then(function(data) {
        if (data.success) {
          // Show success feedback
          button.textContent = 'Done!';
          button.style.backgroundColor = '#28a745';
          button.style.color = '#fff';
          button.style.opacity = '1';

          // Move all unread notifications to read section
          var unreadSection = document.getElementById('bell-unread-section');
          if (unreadSection) {
            var unreadNotifications = unreadSection.querySelectorAll('.bell-notification');
            unreadNotifications.forEach(function(notif) {
              self.moveNotificationToReadSection(notif);
            });
          }

          self.updateUnreadCount();

          // Reset button after 1.5 seconds
          setTimeout(function() {
            button.textContent = originalText;
            button.style.backgroundColor = '';
            button.style.color = '';
            button.style.pointerEvents = '';
          }, 1500);
        }
      })
      .catch(function(error) {
        console.error('BellNotifications: Error marking all as read:', error);
        // Reset button on error
        button.textContent = originalText;
        button.style.opacity = '1';
        button.style.pointerEvents = '';
      });
    },

    moveNotificationToReadSection: function(notification) {
      if (!notification) return;

      // Remove unread styling
      notification.classList.remove('unread');

      // Get or create read section
      var readSection = document.getElementById('bell-read-section');
      var unreadSection = document.getElementById('bell-unread-section');

      if (!readSection) {
        // Create read section if it doesn't exist
        var dropdownList = document.querySelector('.bell-notifications-list');
        if (dropdownList) {
          var readSectionHTML = '<div class="bell-section-header bell-section-collapsible bell-section-collapsed-state" id="bell-read-toggle">' +
            '<h5><span class="bell-collapse-icon"></span> Read (1)</h5>' +
            '</div>' +
            '<div class="bell-section-content bell-section-collapsed" id="bell-read-section"></div>';
          dropdownList.insertAdjacentHTML('beforeend', readSectionHTML);
          readSection = document.getElementById('bell-read-section');
        }
      }

      if (readSection) {
        // Add fade effect
        notification.style.opacity = '0.5';
        setTimeout(function() {
          // Move to read section
          readSection.insertBefore(notification, readSection.firstChild);
          notification.style.opacity = '1';

          // Update counts
          var unreadCount = unreadSection ? unreadSection.querySelectorAll('.bell-notification').length : 0;
          var readCount = readSection.querySelectorAll('.bell-notification').length;

          // Update unread count display
          var unreadCountSpan = document.getElementById('bell-unread-count');
          if (unreadCountSpan) {
            unreadCountSpan.textContent = unreadCount;
          }

          // Update read section header count
          var readToggle = document.getElementById('bell-read-toggle');
          if (readToggle) {
            var readTitle = readToggle.querySelector('h5');
            if (readTitle) {
              readTitle.innerHTML = '<span class="bell-collapse-icon"></span> Read (' + readCount + ')';
            }
          }

          // Hide unread section if empty
          if (unreadCount === 0 && unreadSection) {
            var unreadHeader = unreadSection.previousElementSibling;
            if (unreadHeader && unreadHeader.classList.contains('bell-section-header')) {
              unreadHeader.style.display = 'none';
            }
            unreadSection.style.display = 'none';

            // Hide mark all as read button
            var markAllBtn = document.getElementById('bell-mark-all-read');
            if (markAllBtn) {
              markAllBtn.style.display = 'none';
            }
          }
        }, 300);
      }
    },

    toggleReadSection: function() {
      var readSection = document.getElementById('bell-read-section');
      var readToggle = document.getElementById('bell-read-toggle');

      if (readSection && readToggle) {
        var isCollapsed = readSection.classList.contains('bell-section-collapsed');

        // Toggle collapsed state
        readSection.classList.toggle('bell-section-collapsed');

        // Toggle class on header to control arrow direction
        if (isCollapsed) {
          readToggle.classList.remove('bell-section-collapsed-state');
        } else {
          readToggle.classList.add('bell-section-collapsed-state');
        }
      }
    },

    toggleDropdown: function() {
      if (this.dropdownOpen) {
        this.closeDropdown();
      } else {
        this.openDropdown();
      }
    },

    openDropdown: function() {
      var self = this;

      fetch('/bell_notifications/dropdown', {
        method: 'GET',
        headers: {
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      .then(function(response) {
        return response.text();
      })
      .then(function(html) {
        // Remove any existing dropdown
        var existing = document.querySelector('.bell-notifications-dropdown');
        if (existing) {
          existing.remove();
        }

        // Insert dropdown HTML relative to the bell menu item
        var menu = document.getElementById('bell-notifications-menu');
        if (menu) {
          // Create a container that will be positioned relative to the icon
          var container = document.createElement('div');
          container.style.position = 'relative';
          container.style.display = 'inline-block';
          container.innerHTML = html;

          // Insert after the bell icon
          menu.parentNode.insertBefore(container, menu.nextSibling);
          self.dropdownOpen = true;
        } else {
          console.error('BellNotifications: Could not find bell menu element');
        }
      })
      .catch(function(error) {
        console.error('BellNotifications: Error loading dropdown:', error);
      });
    },

    closeDropdown: function() {
      var dropdown = document.querySelector('.bell-notifications-dropdown');
      if (dropdown) {
        // Remove the parent container that was created
        var parent = dropdown.parentNode;
        if (parent && parent.parentNode) {
          parent.remove();
        } else {
          dropdown.remove();
        }
      }
      this.dropdownOpen = false;
    },

    getCSRFToken: function() {
      var meta = document.querySelector('meta[name="csrf-token"]');
      return meta ? meta.getAttribute('content') : '';
    }
  };

  // Initialize when script loads
  BellNotifications.init();

  // Expose to global scope if needed
  window.BellNotifications = BellNotifications;
})();
