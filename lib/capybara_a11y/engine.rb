module CapybaraA11y
  class Engine < ::Rails::Engine
    config.capybara_a11y = ActiveSupport::OrderedOptions.new
    config.capybara_a11y.audit_after = %i[
      visit
      click_button
      click_link
      click_link_or_button
      click_on
    ]
    config.capybara_a11y.audit_enabled = true

    ActiveSupport.on_load :action_dispatch_system_test_case do
      include CapybaraA11y::AuditSystemTestExtensions

      self.accessibility_audit_enabled = Rails.configuration.capybara_a11y.audit_enabled

      accessibility_audit_after Rails.configuration.capybara_a11y.audit_after
    end
  end
end
