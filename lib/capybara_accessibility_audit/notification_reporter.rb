module CapybaraAccessibilityAudit
  class NotificationReporter
    def initialize(test)
      @test = test
    end

    def report(results)
      if results.violations.present?
        publish(results)
      end
    end

    private

    def publish(report)
      ActiveSupport::Notifications.instrument "report.capybara_accessibility_audit", {
        auditor: @test.accessibility_audit_auditor,
        options: @test.accessibility_audit_options,
        report: report,
        test: @test
      }
    end
  end
end
