require "application_system_test_case"
require "active_support/log_subscriber/test_helper"

module CapybaraAccessibilityAudit
  class LogSubscriber::LogReporterTest < ApplicationSystemTestCase
    include ActiveSupport::LogSubscriber::TestHelper

    self.accessibility_audit_reporter = :log

    def setup
      super
      LogSubscriber.attach_to :capybara_accessibility_audit
    end

    test "does not log reports without violations" do
      visit violations_path

      wait

      assert_empty @logger.logged(:error)
    end

    test "logs violations detected after #click_on" do
      visit violations_path
      click_on "Violate rule: label"

      wait

      assert_equal 1, @logger.logged(:error).size
      assert_match "[capybara_accessibility_audit]", @logger.logged(:error).first
      assert_match "label: Form elements must have labels", @logger.logged(:error).first
    end
  end

  class LogSubscriber::NotificationReporterTest < ApplicationSystemTestCase
    include ActiveSupport::LogSubscriber::TestHelper

    self.accessibility_audit_reporter = :notification

    def setup
      super
      LogSubscriber.attach_to :capybara_accessibility_audit
    end

    test "does not logs violations detected" do
      visit violations_path(rules: %w[label])

      wait

      assert_empty @logger.logged(:error)
    end
  end
end
