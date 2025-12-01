require "application_system_test_case"
require "json"
require "tempfile"

class ReporterGoldenTest < ApplicationSystemTestCase
  GOLDEN_FILE = File.join(__dir__, "..", "fixtures", "golden_report.json")
  GOLDEN_FILE_EMPTY = File.join(__dir__, "..", "fixtures", "golden_report_empty.json")

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
    visit violations_path(rules: %w[label])

    CapybaraAccessibilityAudit::Reporter.report!

    actual_json = File.read(@temp_file.path)
    actual_data = JSON.parse(actual_json, symbolize_names: true)

    normalized_actual = normalize_report_data(actual_data)

    if ENV["UPDATE_GOLDEN"]
      # Update golden file
      File.write(GOLDEN_FILE, JSON.pretty_generate(normalized_actual))
      puts "\nGolden file updated: #{GOLDEN_FILE}"
      skip "Golden file updated. Remove UPDATE_GOLDEN env var and re-run tests."
      return
    end

    assert File.exist?(GOLDEN_FILE), "Golden file not found: #{GOLDEN_FILE}. Run with UPDATE_GOLDEN=1 to create it."

    golden_json = File.read(GOLDEN_FILE)
    expected_data = JSON.parse(golden_json, symbolize_names: true)

    assert_equal expected_data.keys.sort, normalized_actual.keys.sort, "Top-level keys don't match"
    assert_equal expected_data[:summary].keys.sort, normalized_actual[:summary].keys.sort, "Summary keys don't match"

    expected_page = expected_data[:violations_by_page].first
    actual_page = normalized_actual[:violations_by_page].first

    assert_equal expected_page[:violations].count, actual_page[:violations].count, "Number of violations doesn't match"

    expected_violation = expected_page[:violations].first
    actual_violation = actual_page[:violations].first

    assert_equal expected_violation.keys.sort, actual_violation.keys.sort, "Violation keys don't match"
    assert_equal expected_violation[:id], actual_violation[:id], "Violation ID doesn't match"
    assert_equal expected_violation[:impact], actual_violation[:impact], "Violation impact doesn't match"

    assert expected_data[:violations_by_rule].any?, "Expected violations_by_rule to have entries"
    expected_rule = expected_data[:violations_by_rule].values.first
    actual_rule = normalized_actual[:violations_by_rule].values.first

    assert_equal expected_rule.keys.sort, actual_rule.keys.sort, "Rule keys don't match"
  end

  test "JSON output with no violations matches empty golden file" do
    visit violations_path

    CapybaraAccessibilityAudit::Reporter.report!

    assert File.exist?(@temp_file.path), "Report file should exist"
    assert File.size(@temp_file.path) > 0, "Report file should not be empty"

    actual_json = File.read(@temp_file.path)
    actual_data = JSON.parse(actual_json, symbolize_names: true)

    normalized_actual = normalize_report_data(actual_data)

    if ENV["UPDATE_GOLDEN"]
      File.write(GOLDEN_FILE_EMPTY, JSON.pretty_generate(normalized_actual))
      puts "\nEmpty golden file updated: #{GOLDEN_FILE_EMPTY}"
      skip "Golden file updated. Remove UPDATE_GOLDEN env var and re-run tests."
      return
    end

    # check golden file
    assert File.exist?(GOLDEN_FILE_EMPTY), "Empty golden file not found: #{GOLDEN_FILE_EMPTY}. Run with UPDATE_GOLDEN=1 to create it."

    golden_json = File.read(GOLDEN_FILE_EMPTY)
    expected_data = JSON.parse(golden_json, symbolize_names: true)

    # Compare structure
    assert_equal expected_data.keys.sort, normalized_actual.keys.sort, "Top-level keys don't match"
    assert_equal 0, normalized_actual[:summary][:total_violations], "Expected 0 violations"
    assert_equal 0, normalized_actual[:summary][:pages_with_violations], "Expected 0 pages with violations"
    assert_equal [], normalized_actual[:violations_by_page], "Expected empty violations_by_page"
    assert_equal({}, normalized_actual[:violations_by_rule], "Expected empty violations_by_rule")
  end

  private

  def normalize_report_data(data)
    normalized = data.deep_dup

    normalized[:summary][:generated_at] = "<TIMESTAMP>"

    normalized[:violations_by_page].each do |page_data|
      page_data[:timestamp] = "<TIMESTAMP>"
      page_data[:url] = page_data[:url].sub(/https?:\/\/[^\/]+/, "http://example.com")
      page_data[:test_engine] = normalize_test_engine(page_data[:test_engine]) if page_data[:test_engine]
      page_data[:test_environment] = normalize_test_environment(page_data[:test_environment]) if page_data[:test_environment]
    end

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
