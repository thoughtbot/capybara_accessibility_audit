require "application_system_test_case"

module CapybaraAccessibilityAudit
  class AxeAuditorTest < ApplicationSystemTestCase
    test "flunks on violations that the page renders after the click" do
      visit violations_path

      assert_rule_violation "image-alt: Images must have alternative text" do
        click_on "Violate rule: image-alt after a delay"
      end
    end

    test "audits at the deadline when the page never stops changing" do
      visit violations_path

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      assert_rule_violation "image-alt: Images must have alternative text" do
        click_on "Violate rule: image-alt while the page keeps changing"
      end
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      # Without the deadline the wait never ends. The bound leaves room for a slow audit on CI.
      assert_operator elapsed, :<, 15
    end

    test "raises the error that axe reports" do
      skip_accessibility_audits { visit violations_path }

      error = assert_raises AxeAuditor::Error do
        assert_no_accessibility_violations checking: "no-such-rule"
      end

      assert_match "no-such-rule", error.message
    end

    test "raises the error when the results cannot be serialized" do
      skip_accessibility_audits { visit violations_path }
      execute_script <<~JS
        window.axe = {
          run: () => {
            const results = {}
            results.self = results
            return Promise.resolve(results)
          }
        }
      JS

      assert_raises AxeAuditor::Error, match: "circular structure" do
        assert_no_accessibility_violations
      end
    end
  end
end
