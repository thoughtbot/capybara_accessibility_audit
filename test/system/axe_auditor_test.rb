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

    test "reports violations in full and other results with one node each" do
      skip_accessibility_audits { visit violations_path(rules: %w[label image-alt]) }
      reports = []
      reporter = Struct.new(:reports) { def report(results) = reports << results }.new(reports)

      assert_no_accessibility_violations auditor: AxeAuditor.new(self, reporter)
      results = reports.sole

      assert_equal %i[image-alt label], results.violations.map(&:id).sort
      assert_not_empty results.passes
      assert results.passes.all? { |rule| rule.nodes.size <= 1 }
    end

    test "overrides the options passed to axe.run" do
      run_options = AxeAuditor.run_options
      AxeAuditor.run_options = {resultTypes: ["violations"], iframes: false, rules: {label: {enabled: false}}}
      skip_accessibility_audits { visit violations_path(rules: %w[label image-alt]) }

      assert_rule_violation with: "image-alt", without: "label: Form elements must have labels" do
        assert_no_accessibility_violations
      end
    ensure
      AxeAuditor.run_options = run_options
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
