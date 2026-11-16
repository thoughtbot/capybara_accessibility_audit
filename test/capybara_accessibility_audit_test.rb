require "test_helper"

class CapybaraAccessibilityAuditTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert CapybaraAccessibilityAudit::VERSION
  end

  test "forwards the configured auditor default options to the auditor" do
    default_options = Rails.configuration.capybara_accessibility_audit.auditor.default_options

    assert_same default_options, CapybaraAccessibilityAudit::AxeAuditor.default_options
    assert_equal({resultTypes: ["violations"], iframes: false}, default_options)
  end

  test "resolves the auditor class from the configuration" do
    auditor_class = Class.new

    assert_equal CapybaraAccessibilityAudit::AxeAuditor, CapybaraAccessibilityAudit.auditor_class(ActiveSupport::OrderedOptions.new)
    assert_equal auditor_class, CapybaraAccessibilityAudit.auditor_class(auditor_class)
  end
end
