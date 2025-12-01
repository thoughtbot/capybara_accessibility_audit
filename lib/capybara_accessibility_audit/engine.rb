module CapybaraAccessibilityAudit
  class Engine < ::Rails::Engine
    config.capybara_accessibility_audit = ActiveSupport::OrderedOptions.new
    config.capybara_accessibility_audit.audit_after = %i[
      visit
      click_button
      click_link
      click_link_or_button
      click_on
    ]
    # audit_enabled accepts: false (disabled), true (assert mode), :assert, :stdout, or { file: 'path' }
    config.capybara_accessibility_audit.audit_enabled = true

    # Minitest
    initializer "capybara_accessibility_audit.minitest" do |app|
      ActiveSupport.on_load :action_dispatch_system_test_case do
        include CapybaraAccessibilityAudit::AuditSystemTestExtensions

        # Use the backwards-compatible accessor which handles conversion
        self.accessibility_audit_enabled = app.config.capybara_accessibility_audit.audit_enabled

        accessibility_audit_after app.config.capybara_accessibility_audit.audit_after
      end
    end

    # RSpec
    initializer "capybara_accessibility_audit.rspec" do |app|
      if defined?(RSpec)
        require "rspec/core"

        RSpec.configure do |config|
          config.include CapybaraAccessibilityAudit::AuditSystemTestExtensions, type: :system
          config.include CapybaraAccessibilityAudit::AuditSystemTestExtensions, type: :feature

          configure = proc do
            self.accessibility_audit_enabled = app.config.capybara_accessibility_audit.audit_enabled

            accessibility_audit_after app.config.capybara_accessibility_audit.audit_after
          end

          config.before(type: :system, &configure)
          config.before(type: :feature, &configure)

          config.after(:suite) do
            Reporter.report!
          end
        end
      end
    end

    # Minitest
    config.after_initialize do
      if defined?(Minitest)
        Minitest.after_run do
          Reporter.report!
        end
      end
    end
  end
end
