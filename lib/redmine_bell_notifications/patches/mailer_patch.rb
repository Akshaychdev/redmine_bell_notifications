module RedmineBellNotifications
  module Patches
    module MailerPatch
      extend ActiveSupport::Concern

      module ClassMethods
        # Intercept mail delivery to create bell notifications
        def deliver_mail(mail)
          # Always create bell notifications, regardless of email delivery settings
          # This allows bell notifications to work independently of email configuration
          begin
            Rails.logger.info "BellNotifications: deliver_mail called - Subject: #{mail.subject}, To: #{mail.to.inspect}"
            create_bell_notifications(mail)

            # Trigger automatic cleanup if due (runs in background, doesn't block)
            RedmineBellNotifications.auto_cleanup
          rescue => e
            Rails.logger.error "BellNotifications: Error creating notifications: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
          end

          # Continue with normal email delivery
          # Call super without arguments to preserve original behavior and return value
          super
        end

        private

        def create_bell_notifications(mail)
          builder = NotificationBuilder.new(mail)

          # Process all recipients (to, cc, bcc)
          %i(to cc bcc).each do |field|
            receivers = Array(mail.send(field)).flatten.compact
            Rails.logger.info "BellNotifications: #{field.upcase} recipients: #{receivers.inspect}"

            receivers.each do |addr|
              user = User.having_mail(addr).first

              if user.present?
                should_create = should_create_bell_notification?(user)
                Rails.logger.info "BellNotifications: User found: #{user.login} (#{addr}), should_create: #{should_create}"

                if should_create
                  notification = builder.create_notification_for(user)
                  Rails.logger.info "BellNotifications: Notification created: #{notification.inspect}"
                end
              else
                Rails.logger.info "BellNotifications: No user found for email: #{addr}"
              end
            end
          end
        end

        # Check if we should create a bell notification for this user
        def should_create_bell_notification?(user)
          # User must be active and logged (not anonymous)
          return false unless user.active? && user.logged?

          # Respect user's email notification settings
          # If user has mail_notification = 'none', they don't want notifications
          return false if user.mail_notification == 'none'

          # Create bell notifications for all other cases
          true
        end
      end
    end
  end
end
