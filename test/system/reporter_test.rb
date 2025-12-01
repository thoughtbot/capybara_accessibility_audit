require "application_system_test_case"
require "json"
require "tempfile"

class ReporterStdoutTest < ApplicationSystemTestCase
  self.accessibility_audit_enabled = :stdout

  setup do
    CapybaraAccessibilityAudit::Reporter.clear!
  end

  test "collects violations without failing tests" do
    visit violations_path(rules: %w[label])

    # Test should pass even though there are violations
    assert_equal 1, CapybaraAccessibilityAudit::Reporter.violations.count
  end

  test "collects violations with structured data" do
    visit violations_path(rules: %w[label])

    violations = CapybaraAccessibilityAudit::Reporter.violations
    assert_equal 1, violations.count

    violation_data = violations.first
    assert_includes violation_data[:url], "/violations"
    assert_kind_of String, violation_data[:timestamp]
    assert_kind_of Array, violation_data[:violations]

    # Check structured violation data
    rule_violation = violation_data[:violations].first
    assert_equal :label, rule_violation[:id]
    assert_equal :critical, rule_violation[:impact]
    assert_kind_of String, rule_violation[:description]
    assert_kind_of String, rule_violation[:help]
    assert_kind_of String, rule_violation[:helpUrl]
    assert_kind_of Array, rule_violation[:tags]
    assert_kind_of Array, rule_violation[:nodes]
  end

  test "collects multiple violations across pages" do
    visit violations_path(rules: %w[label])
    visit violations_path(rules: %w[image-alt])

    assert_equal 2, CapybaraAccessibilityAudit::Reporter.violations.count
  end
end

class ReporterJsonFileTest < ApplicationSystemTestCase
  setup do
    CapybaraAccessibilityAudit::Reporter.clear!
    @temp_file = Tempfile.new(["accessibility_violations", ".json"])
    @temp_file.close
    self.accessibility_audit_enabled = {file: @temp_file.path}
  end

  teardown do
    @temp_file&.unlink
  end

  test "writes JSON report to file" do
    visit violations_path(rules: %w[label])

    # Manually trigger report output (normally done at end of test run)
    CapybaraAccessibilityAudit::Reporter.report!

    assert File.exist?(@temp_file.path)
    json_content = File.read(@temp_file.path)
    report_data = JSON.parse(json_content, symbolize_names: true)

    # Verify JSON structure
    assert_kind_of Hash, report_data
    assert_includes report_data, :summary
    assert_includes report_data, :violations_by_page
    assert_includes report_data, :violations_by_rule

    # Verify summary
    summary = report_data[:summary]
    assert summary[:total_violations] > 0
    assert_equal 1, summary[:num_pages_with_violations]
    assert_kind_of String, summary[:generated_at]

    # Verify violations by page
    assert_equal 1, report_data[:violations_by_page].count
    page_data = report_data[:violations_by_page].first
    assert_includes page_data[:url], "/violations"
    assert_kind_of String, page_data[:timestamp]
    assert page_data[:violations].count > 0

    # Verify violations by rule
    assert report_data[:violations_by_rule].count > 0
    rule_data = report_data[:violations_by_rule].values.first
    assert_includes rule_data, :impact
    assert_includes rule_data, :description
    assert_includes rule_data, :help
    assert_includes rule_data, :helpUrl
    assert_includes rule_data, :tags
    assert_includes rule_data, :num_occurrences
    assert_includes rule_data, :pages
  end

  test "groups violations by rule across multiple pages" do
    visit violations_path(rules: %w[label])
    visit violations_path(rules: %w[label image-alt])

    CapybaraAccessibilityAudit::Reporter.report!

    json_content = File.read(@temp_file.path)
    report_data = JSON.parse(json_content, symbolize_names: true)

    # Should have label violations from both pages
    label_rule = report_data[:violations_by_rule][:label]
    assert_equal 2, label_rule[:pages].count
    assert label_rule[:num_occurrences] >= 2
  end
end

class ReporterDisabledTest < ApplicationSystemTestCase
  self.accessibility_audit_enabled = false

  setup do
    CapybaraAccessibilityAudit::Reporter.clear!
  end

  test "does not collect violations when disabled" do
    visit violations_path(rules: %w[label])

    # Should have no violations collected because audits are disabled
    assert_equal 0, CapybaraAccessibilityAudit::Reporter.violations.count
  end
end
