require "application_system_test_case"
require "json"
require "tempfile"

class ReporterGoldenTest < ApplicationSystemTestCase
  GOLDEN_FILE = File.join(__dir__, "..", "fixtures", "golden_report.json")

  setup do
    CapybaraAccessibilityAudit::Reporter.clear!
    @temp_file = Tempfile.new(["accessibility_violations", ".json"])
    @temp_file.close
    self.accessibility_audit_enabled = {file: @temp_file.path}
  end

  teardown do
    @temp_file&.unlink
  end

  test "JSON output matches golden file structure" do
    # Visit page with known violations
    visit violations_path(rules: %w[label])

    # Generate report
    CapybaraAccessibilityAudit::Reporter.report!

    # Read generated JSON
    actual_json = File.read(@temp_file.path)
    actual_data = JSON.parse(actual_json, symbolize_names: true)

    # Normalize dynamic fields for comparison
    normalized_actual = normalize_report_data(actual_data)

    if ENV["UPDATE_GOLDEN"]
      # Update golden file
      File.write(GOLDEN_FILE, JSON.pretty_generate(normalized_actual))
      puts "\nGolden file updated: #{GOLDEN_FILE}"
      skip "Golden file updated. Remove UPDATE_GOLDEN env var and re-run tests."
    else
      # Compare with golden file
      assert File.exist?(GOLDEN_FILE), "Golden file not found: #{GOLDEN_FILE}. Run with UPDATE_GOLDEN=1 to create it."

      golden_json = File.read(GOLDEN_FILE)
      expected_data = JSON.parse(golden_json, symbolize_names: true)

      # Compare structure
      assert_equal expected_data.keys.sort, normalized_actual.keys.sort, "Top-level keys don't match"
      assert_equal expected_data[:summary].keys.sort, normalized_actual[:summary].keys.sort, "Summary keys don't match"

      # Compare violations structure (not exact values, since URLs may vary)
      expected_page = expected_data[:violations_by_page].first
      actual_page = normalized_actual[:violations_by_page].first

      assert_equal expected_page[:violations].count, actual_page[:violations].count, "Number of violations doesn't match"

      expected_violation = expected_page[:violations].first
      actual_violation = actual_page[:violations].first

      assert_equal expected_violation.keys.sort, actual_violation.keys.sort, "Violation keys don't match"
      assert_equal expected_violation[:id], actual_violation[:id], "Violation ID doesn't match"
      assert_equal expected_violation[:impact], actual_violation[:impact], "Violation impact doesn't match"

      # Verify violations_by_rule structure
      assert expected_data[:violations_by_rule].any?, "Expected violations_by_rule to have entries"
      expected_rule = expected_data[:violations_by_rule].values.first
      actual_rule = normalized_actual[:violations_by_rule].values.first

      assert_equal expected_rule.keys.sort, actual_rule.keys.sort, "Rule keys don't match"
    end
  end

  private

  def normalize_report_data(data)
    # Create a normalized copy with predictable values for dynamic fields
    normalized = data.deep_dup

    # Normalize timestamps
    normalized[:summary][:generated_at] = "<TIMESTAMP>"

    normalized[:violations_by_page].each do |page_data|
      page_data[:timestamp] = "<TIMESTAMP>"
      # Keep URL structure but normalize the domain
      page_data[:url] = page_data[:url].sub(/https?:\/\/[^\/]+/, "http://example.com")
      page_data[:test_engine] = normalize_test_engine(page_data[:test_engine]) if page_data[:test_engine]
      page_data[:test_environment] = normalize_test_environment(page_data[:test_environment]) if page_data[:test_environment]
    end

    # Normalize page URLs in violations_by_rule
    normalized[:violations_by_rule].each do |_rule_id, rule_data|
      rule_data[:pages] = rule_data[:pages].map do |url|
        url.sub(/https?:\/\/[^\/]+/, "http://example.com")
      end
    end

    normalized
  end

  def normalize_test_engine(engine)
    return nil unless engine
    engine.merge(version: "VERSION")
  end

  def normalize_test_environment(env)
    return nil unless env
    env.merge(
      userAgent: "USER_AGENT",
      windowWidth: 0,
      windowHeight: 0
    )
  end
end
