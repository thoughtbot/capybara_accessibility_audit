module CapybaraAccessibilityAudit
  class LogSubscriber < ActiveSupport::LogSubscriber
    def report(event)
      report = event.payload[:report]
      test = event.payload[:test]

      if test.accessibility_audit_reporter == :log
        error color(<<~ERROR, :red)
          [capybara_accessibility_audit] Accessibility audit detected violations in "#{test.class.name}##{test.name}":
          #{report.failure_message}
        ERROR
      end
    end

    attach_to :capybara_accessibility_audit
  end
end
