module CapybaraAccessibilityAudit
  class Engine < ::Rails::Engine
    config.capybara_accessibility_audit = ActiveSupport::OrderedOptions.new
    config.capybara_accessibility_audit.auditor = AxeAuditor
    config.capybara_accessibility_audit.audit_after = %i[
      visit
      click_button
      click_link
      click_link_or_button
      click_on
    ]
    config.capybara_accessibility_audit.audit_enabled = true
    config.capybara_accessibility_audit.reporter = RaiseReporter

    initializer "capybara_accessibility_audit.minitest" do |app|
      ActiveSupport.on_load :action_dispatch_system_test_case do
        include CapybaraAccessibilityAudit::AuditSystemTestExtensions

        self.accessibility_audit_enabled = app.config.capybara_accessibility_audit.audit_enabled

        accessibility_audit_after app.config.capybara_accessibility_audit.audit_after

        setup do
          auditor_class = app.config.capybara_accessibility_audit.auditor
          reporter_class = app.config.capybara_accessibility_audit.reporter

          @accessibility_audit_auditor = auditor_class.new(page, reporter_class.new(self))
        end
      end
    end

    initializer "capybara_accessibility_audit.rspec" do |app|
      if defined?(RSpec)
        require "rspec/core"

        RSpec.configure do |config|
          config.include CapybaraAccessibilityAudit::AuditSystemTestExtensions, type: :system
          config.include CapybaraAccessibilityAudit::AuditSystemTestExtensions, type: :feature

          configure = proc do
            self.accessibility_audit_enabled = app.config.capybara_accessibility_audit.audit_enabled

            accessibility_audit_after app.config.capybara_accessibility_audit.audit_after

            auditor_class = app.config.capybara_accessibility_audit.auditor
            reporter_class = app.config.capybara_accessibility_audit.reporter

            @accessibility_audit_auditor = auditor_class.new(page, reporter_class.new(self))
          end

          config.before(type: :system, &configure)
          config.before(type: :feature, &configure)
        end
      end
    end
  end
end
