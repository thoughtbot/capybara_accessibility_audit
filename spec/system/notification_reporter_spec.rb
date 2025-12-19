require "spec_helper"

RSpec.describe "Audit assertions", type: :system, js: true do
  before :all do
    driven_by Capybara.javascript_driver
    self.accessibility_audit_reporter = :notification
  end

  it "does not report when there are no violations detected" do
    expect do
      visit violations_path

      expect(page).to have_link("Violate rule: label")
    end.to emit_event("report.capybara_accessibility_audit").exactly(0).times
  end

  it "reports on violations detected after #visit" do
    assert_rule_violation "label: Form elements must have labels" do
      visit violations_path(rules: %w[label])
    end
  end

  it "reports on violations detected after #click_on" do
    visit violations_path

    assert_rule_violation "label: Form elements must have labels" do
      click_on "Violate rule: label"
    end
  end

  it "reports on violations detected after #click_link" do
    visit violations_path

    assert_rule_violation "label: Form elements must have labels" do
      click_link "Violate rule: label"
    end
  end

  describe "Skipping Audit After Method" do
    skip_accessibility_audit_after :visit, :click_on

    it "does not audit after a skipped method" do
      visit violations_path
      click_on "Violate rule: label"
      go_back

      assert_rule_violation("label: Form elements must have labels") do
        click_link "Violate rule: label"
      end
    end
  end

  def capture_report(&block)
    notification = nil

    ActiveSupport::Notifications.subscribed(->(event) { notification = event }, "report.capybara_accessibility_audit", &block)

    assert_equal self, notification.payload[:test]
    assert_kind_of CapybaraAccessibilityAudit::AxeAuditor, notification.payload[:auditor]

    notification.payload[:report].failure_message
  end
end
