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

    assert_equal expected_data, normalized_actual
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
    assert_equal expected_data, normalized_actual
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
