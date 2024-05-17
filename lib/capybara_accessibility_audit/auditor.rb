module CapybaraAccessibilityAudit
  class Auditor
    delegate_missing_to :@test

    def initialize(test)
      @test = test
    end

    def audit!(method)
      if accessibility_audit_enabled && method.in?(accessibility_audit_after_methods) && javascript_enabled?
        axe_matcher = audit_accessibility_violations(**accessibility_audit_options)
        audit = axe_matcher.audit(page)

        if (violations = audit.results.violations.presence)
          @test.accessibility_violations += violations
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
