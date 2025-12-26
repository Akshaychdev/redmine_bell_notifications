module RedmineBellNotifications
  module Patches
    module MailerPatch
      extend ActiveSupport::Concern

      module ClassMethods
        # Intercept mail delivery to create bell notifications
        #
        # @param mail [Mail::Message] The email message being delivered
        # @return [Mail::Message] The delivered mail message
        def deliver_mail(mail)
          # Always create bell notifications, regardless of email delivery settings
          # This allows bell notifications to work independently of email configuration
          begin
            RedmineBellNotifications::Logger.info(
              "Mail delivery intercepted",
              context: { subject: mail.subject, recipients: mail.to&.size || 0 }
            )
            create_bell_notifications(mail)

            # Trigger automatic cleanup if due (runs in background, doesn't block)
            RedmineBellNotifications.auto_cleanup
          rescue => e
            RedmineBellNotifications::Logger.error(
              "Failed to create bell notifications during mail delivery",
              exception: e,
              context: { subject: mail.subject }
            )
          end

          # Continue with normal email delivery
          # Call super without arguments to preserve original behavior and return value
          super
        end

        private

        # Create bell notifications for all mail recipients
        #
        # @param mail [Mail::Message] The email message to process
        # @return [void]
        def create_bell_notifications(mail)
          builder = NotificationBuilder.new(mail)

          # Process all recipients (to, cc, bcc)
          %i(to cc bcc).each do |field|
            receivers = Array(mail.send(field)).flatten.compact
            RedmineBellNotifications::Logger.debug(
              "Processing recipients",
              context: { field: field, count: receivers.size }
            )

            receivers.each do |addr|
              user = User.having_mail(addr).first

              if user.present?
                should_create = should_create_bell_notification?(user)
                RedmineBellNotifications::Logger.debug(
                  "User found",
                  context: { user_login: user.login, email: addr, will_create: should_create }
                )

                if should_create
                  notification = builder.create_notification_for(user)
                  if notification
                    RedmineBellNotifications::Logger.debug(
                      "Notification created",
                      context: { notification_id: notification.id, user_id: user.id }
                    )
                  end
                end
              else
                RedmineBellNotifications::Logger.debug(
                  "No user found for email",
                  context: { email: addr }
                )
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
