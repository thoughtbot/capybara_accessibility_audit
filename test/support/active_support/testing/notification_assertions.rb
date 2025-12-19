module ActiveSupport::Testing
  unless defined?(NotificationAssertions)
    module NotificationAssertions
      def assert_notification(pattern, payload = nil, &block)
        notifications = capture_notifications(pattern, &block)
        assert_not_empty(notifications, "No #{pattern} notifications were found")

        return notifications.first if payload.nil?

        notification = notifications.find { |notification| notification.payload.slice(*payload.keys) == payload }
        assert_not_nil(notification, "No #{pattern} notification with payload #{payload} was found")

        notification
      end

      def assert_notifications_count(pattern, count, &block)
        actual_count = capture_notifications(pattern, &block).count
        assert_equal(count, actual_count, "Expected #{count} instead of #{actual_count} notifications for #{pattern}")
      end

      def assert_no_notifications(pattern = nil, &block)
        notifications = capture_notifications(pattern, &block)
        error_message = if pattern
          "Expected no notifications for #{pattern} but found #{notifications.size}"
        else
          "Expected no notifications but found #{notifications.size}"
        end
        assert_empty(notifications, error_message)
      end

      def capture_notifications(pattern = nil, &block)
        notifications = []
        ActiveSupport::Notifications.subscribed(->(n) { notifications << n }, pattern, &block)
        notifications
      end
    end

    ActiveSupport.on_load(:active_support_test_case) { include NotificationAssertions }
  end
end
