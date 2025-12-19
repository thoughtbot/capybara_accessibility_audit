require "application_system_test_case"

module CapybaraAccessibilityAudit
  class NotificationReporter::TestCase < ApplicationSystemTestCase
    self.accessibility_audit_reporter = :notification

    def capture_report(&block)
      notification = assert_notification("report.capybara_accessibility_audit", &block)

      assert_equal self, notification.payload[:test]
      assert_kind_of AxeAuditor, notification.payload[:auditor]

      notification.payload[:report].failure_message
    end
  end

  class NotificationReporter::AuditAssertionsTest < NotificationReporter::TestCase
    test "does not report when there are no violations detected" do
      assert_no_notifications "report.capybara_accessibility_audit" do
        visit violations_path

        assert_link "Violate rule: label"
      end
    end

    test "reports on violations detected after #visit" do
      assert_rule_violation "label: Form elements must have labels" do
        visit violations_path(rules: %w[label])
      end
    end

    test "reports on violations detected after #click_on" do
      visit violations_path

      assert_rule_violation "label: Form elements must have labels" do
        click_on "Violate rule: label"
      end
    end

    test "reports on violations detected after #click_link" do
      visit violations_path

      assert_rule_violation "label: Form elements must have labels" do
        click_link "Violate rule: label"
      end
    end
  end

  class NotificationReporter::SkippingAuditAfterMethodTest < NotificationReporter::TestCase
    skip_accessibility_audit_after :visit, :click_on

    test "does not audit after a skipped method" do
      visit violations_path
      click_on "Violate rule: label"
      go_back

      assert_rule_violation("label: Form elements must have labels") do
        click_link "Violate rule: label"
      end
    end
  end
end
