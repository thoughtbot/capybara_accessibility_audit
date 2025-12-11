module CapybaraAccessibilityAudit
  class RaiseReporter
    def initialize(test)
      @test = test
    end

    def report(results)
      @test.assert results.violations.empty?, -> { results.failure_message }
    end
  end
end
