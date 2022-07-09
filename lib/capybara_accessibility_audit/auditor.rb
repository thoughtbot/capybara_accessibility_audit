module CapybaraAccessibilityAudit
  class Auditor
    delegate_missing_to :@test

    def initialize(test)
      @test = test
    end

    def audit!(method)
      if accessibility_audit_enabled && method.in?(accessibility_audit_after_methods)
        assert_no_accessibility_violations(**accessibility_audit_options)
      end
    end
  end
end
