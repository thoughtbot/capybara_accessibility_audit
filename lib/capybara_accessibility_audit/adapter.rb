module CapybaraAccessibilityAudit
  class Adapter
    delegate_missing_to :@test

    def initialize(test)
      @test = test
    end

    def audit!(method)
      if accessibility_audit_enabled && method.in?(accessibility_audit_after_methods) && javascript_enabled?
        ActiveSupport::Notifications.instrument "audit.capybara_accessibility_audit" do |payload|
          payload[:method] = method
          payload[:options] = accessibility_audit_options
          payload[:test] = @test

          assert_no_accessibility_violations(**accessibility_audit_options)
        end
      end
    end

    private

    def javascript_enabled?
      case page.driver
      when Capybara::RackTest::Driver then false
      else true
      end
    end
  end
end
