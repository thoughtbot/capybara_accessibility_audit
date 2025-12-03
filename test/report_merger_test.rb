require "test_helper"
require "capybara_accessibility_audit/report_merger"
require "json"
require "tempfile"

module CapybaraAccessibilityAudit
  class ReportMergerTest < ActiveSupport::TestCase
    setup do
      @temp_dir = Dir.mktmpdir
    end

    teardown do
      FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
    end

    test "merges two simple reports with disjoint pages" do
      report1 = create_report(pages: [create_page(url: "http://example.com/page1")])
      report2 = create_report(pages: [create_page(url: "http://example.com/page2")])

      merged = ReportMerger.merge_data([report1, report2])

      assert_equal 2, merged[:violations_by_page].count
      assert_equal 2, merged[:summary][:num_pages_with_violations]
      assert_equal 2, merged[:summary][:total_violations]
    end

    test "merges violations for duplicate URLs" do
      page1 = create_page(url: "http://example.com/page", violations: [create_violation(id: "label")])
      page2 = create_page(url: "http://example.com/page", violations: [create_violation(id: "image-alt")])

      report1 = create_report(pages: [page1])
      report2 = create_report(pages: [page2])

      merged = ReportMerger.merge_data([report1, report2])

      assert_equal 1, merged[:violations_by_page].count
      assert_equal 2, merged[:violations_by_page].first[:violations].count
      assert_equal ["image-alt", "label"],
        merged[:violations_by_page].first[:violations].map { |v| v[:id] }.sort
    end

    test "deduplicates nodes with same target" do
      violation1 = create_violation(id: "label", nodes: [create_node(target: ["input#email"])])
      violation2 = create_violation(id: "label", nodes: [create_node(target: ["input#email"])])

      page1 = create_page(url: "http://example.com", violations: [violation1])
      page2 = create_page(url: "http://example.com", violations: [violation2])

      merged = ReportMerger.merge_data([
        create_report(pages: [page1]),
        create_report(pages: [page2])
      ])

      assert_equal 1, merged[:violations_by_page].first[:violations].first[:nodes].count
    end

    test "keeps different nodes with different targets" do
      violation1 = create_violation(id: "label", nodes: [create_node(target: ["input#email"])])
      violation2 = create_violation(id: "label", nodes: [create_node(target: ["input#password"])])

      page1 = create_page(url: "http://example.com", violations: [violation1])
      page2 = create_page(url: "http://example.com", violations: [violation2])

      merged = ReportMerger.merge_data([
        create_report(pages: [page1]),
        create_report(pages: [page2])
      ])

      assert_equal 2, merged[:violations_by_page].first[:violations].first[:nodes].count
    end

    test "uses latest timestamp for duplicate pages" do
      older = "2024-01-01T10:00:00Z"
      newer = "2024-01-01T11:00:00Z"

      page1 = create_page(url: "http://example.com", timestamp: older)
      page2 = create_page(url: "http://example.com", timestamp: newer)

      merged = ReportMerger.merge_data([
        create_report(pages: [page1]),
        create_report(pages: [page2])
      ])

      assert_equal newer, merged[:violations_by_page].first[:timestamp]
    end

    test "uses latest generated_at in summary" do
      report1 = create_report(generated_at: "2024-01-01T10:00:00Z")
      report2 = create_report(generated_at: "2024-01-01T11:00:00Z")

      merged = ReportMerger.merge_data([report1, report2])

      assert_equal "2024-01-01T11:00:00Z", merged[:summary][:generated_at]
    end

    test "aggregates violations_by_rule across reports" do
      report1 = create_report_with_rule("label", pages: ["page1"], num_occurrences: 2)
      report2 = create_report_with_rule("label", pages: ["page2"], num_occurrences: 3)

      merged = ReportMerger.merge_data([report1, report2])

      assert_equal 5, merged[:violations_by_rule]["label"][:num_occurrences]
      assert_equal ["page1", "page2"].sort,
        merged[:violations_by_rule]["label"][:pages].sort
    end

    test "recalculates summary correctly" do
      report1 = create_report_with_impacts(critical: 2, serious: 1, offset: 0)
      report2 = create_report_with_impacts(critical: 1, moderate: 3, offset: 10)

      merged = ReportMerger.merge_data([report1, report2])

      assert_equal 7, merged[:summary][:total_violations]
      assert_equal 3, merged[:summary][:num_violations_by_impact]["critical"]
      assert_equal 1, merged[:summary][:num_violations_by_impact]["serious"]
      assert_equal 3, merged[:summary][:num_violations_by_impact]["moderate"]
      assert_equal 0, merged[:summary][:num_violations_by_impact]["minor"]
    end

    test "handles empty report list" do
      merged = ReportMerger.merge_data([])

      assert_equal 0, merged[:summary][:total_violations]
      assert_equal 0, merged[:summary][:num_pages_with_violations]
      assert_equal [], merged[:violations_by_page]
      assert_equal({}, merged[:violations_by_rule])
    end

    test "handles single report" do
      report = create_report(pages: [create_page])

      merged = ReportMerger.merge_data([report])

      assert_equal report[:summary][:total_violations],
        merged[:summary][:total_violations]
    end

    test "handles reports with no violations" do
      report1 = empty_report
      report2 = empty_report

      merged = ReportMerger.merge_data([report1, report2])

      assert_equal 0, merged[:summary][:total_violations]
    end

    test "writes merged report to file" do
      output_path = File.join(@temp_dir, "merged.json")
      input_files = create_temp_reports(2)

      ReportMerger.merge(
        report_paths: input_files,
        output_path: output_path
      )

      assert File.exist?(output_path)
      parsed = JSON.parse(File.read(output_path), symbolize_names: true)

      assert_equal 2, parsed[:summary][:total_violations]
      assert_equal 2, parsed[:summary][:num_pages_with_violations]
      assert_equal 2, parsed[:violations_by_page].count
    end

    test "creates output directory if missing" do
      output_path = File.join(@temp_dir, "subdir", "merged.json")
      input_files = create_temp_reports(1)

      ReportMerger.merge(
        report_paths: input_files,
        output_path: output_path
      )

      assert File.exist?(output_path)
    end

    test "raises error for empty input paths" do
      error = assert_raises(ArgumentError) do
        ReportMerger.merge(report_paths: [], output_path: "out.json")
      end
      assert_match(/No report paths/, error.message)
    end

    test "raises error for non-existent file" do
      error = assert_raises(ArgumentError) do
        ReportMerger.merge(
          report_paths: ["nonexistent.json"],
          output_path: "out.json"
        )
      end
      assert_match(/File not found/, error.message)
    end

    test "raises error for invalid JSON" do
      bad_file = File.join(@temp_dir, "invalid.json")
      File.write(bad_file, "invalid json content")

      error = assert_raises(JSON::ParserError) do
        ReportMerger.merge(
          report_paths: [bad_file],
          output_path: "out.json"
        )
      end
      assert_match(/Invalid JSON/, error.message)
    end

    test "sorts violations_by_rule by impact and occurrences" do
      report = create_report(
        pages: [],
        violations_by_rule: {
          "minor-rule" => create_rule_data(impact: "minor", num_occurrences: 100),
          "critical-rule" => create_rule_data(impact: "critical", num_occurrences: 50),
          "serious-rule" => create_rule_data(impact: "serious", num_occurrences: 75)
        }
      )

      merged = ReportMerger.merge_data([report])

      rule_ids = merged[:violations_by_rule].keys
      assert_equal ["critical-rule", "serious-rule", "minor-rule"], rule_ids
    end

    private

    def create_report(pages: [], violations_by_rule: {}, generated_at: "2024-01-01T10:00:00Z")
      violations_by_rule = build_violations_by_rule(pages) if violations_by_rule.empty? && pages.any?

      {
        summary: {
          total_violations: calculate_total(pages),
          num_pages_with_violations: pages.count { |p| p[:violations].any? },
          num_violations_by_impact: calculate_impacts(pages),
          generated_at: generated_at
        },
        violations_by_rule: violations_by_rule,
        violations_by_page: pages
      }
    end

    def create_report_with_rule(rule_id, pages:, num_occurrences:)
      {
        summary: {
          total_violations: num_occurrences,
          num_pages_with_violations: pages.count,
          num_violations_by_impact: {"critical" => num_occurrences, "serious" => 0, "moderate" => 0, "minor" => 0},
          generated_at: "2024-01-01T10:00:00Z"
        },
        violations_by_rule: {
          rule_id => create_rule_data(
            id: rule_id,
            impact: "critical",
            num_occurrences: num_occurrences,
            pages: pages
          )
        },
        violations_by_page: []
      }
    end

    def create_report_with_impacts(critical: 0, serious: 0, moderate: 0, minor: 0, offset: 0)
      pages = []
      counter = offset
      pages += Array.new(critical) {
        counter += 1
        create_page(url: "http://example.com/page#{counter}", violations: [create_violation(impact: "critical")])
      }
      pages += Array.new(serious) {
        counter += 1
        create_page(url: "http://example.com/page#{counter}", violations: [create_violation(impact: "serious")])
      }
      pages += Array.new(moderate) {
        counter += 1
        create_page(url: "http://example.com/page#{counter}", violations: [create_violation(impact: "moderate")])
      }
      pages += Array.new(minor) {
        counter += 1
        create_page(url: "http://example.com/page#{counter}", violations: [create_violation(impact: "minor")])
      }

      create_report(pages: pages)
    end

    def create_page(url: "http://example.com", violations: nil, timestamp: "2024-01-01T10:00:00Z")
      violations ||= [create_violation]

      {
        url: url,
        timestamp: timestamp,
        violations: violations,
        test_engine: {name: "axe-core", version: "4.11.0"},
        test_environment: {userAgent: "Test", windowWidth: 1024, windowHeight: 768}
      }
    end

    def create_violation(id: "label", impact: "critical", nodes: nil)
      nodes ||= [create_node]

      {
        id: id,
        impact: impact,
        description: "Test violation",
        help: "Fix this issue",
        helpUrl: "https://example.com/help",
        tags: ["wcag2a"],
        nodes: nodes
      }
    end

    def create_node(target: ["input"], html: "<input>")
      {
        html: html,
        target: target,
        failureSummary: "Element has issues",
        impact: "critical"
      }
    end

    def create_rule_data(id: "label", impact: "critical", num_occurrences: 1, pages: ["page1"])
      {
        impact: impact,
        description: "Test rule",
        help: "Fix this",
        helpUrl: "https://example.com/help",
        tags: ["wcag2a"],
        num_occurrences: num_occurrences,
        pages: pages
      }
    end

    def empty_report
      {
        summary: {
          total_violations: 0,
          num_pages_with_violations: 0,
          num_violations_by_impact: {"critical" => 0, "serious" => 0, "moderate" => 0, "minor" => 0},
          generated_at: "2024-01-01T10:00:00Z"
        },
        violations_by_rule: {},
        violations_by_page: []
      }
    end

    def calculate_total(pages)
      pages.sum { |p| p[:violations].sum { |v| v[:nodes].count } }
    end

    def calculate_impacts(pages)
      counts = Hash.new(0)
      pages.each do |page|
        page[:violations].each do |violation|
          counts[violation[:impact]] += violation[:nodes].count
        end
      end
      {"critical" => counts["critical"], "serious" => counts["serious"], "moderate" => counts["moderate"], "minor" => counts["minor"]}
    end

    def build_violations_by_rule(pages)
      rules = {}
      pages.each do |page|
        page[:violations].each do |violation|
          rule_id = violation[:id]
          rules[rule_id] ||= {
            impact: violation[:impact],
            description: violation[:description],
            help: violation[:help],
            helpUrl: violation[:helpUrl],
            tags: violation[:tags],
            num_occurrences: 0,
            pages: []
          }
          rules[rule_id][:num_occurrences] += violation[:nodes].count
          rules[rule_id][:pages] << page[:url] unless rules[rule_id][:pages].include?(page[:url])
        end
      end
      rules
    end

    def create_temp_reports(count)
      count.times.map do |i|
        file_path = File.join(@temp_dir, "report_#{i}.json")
        report = create_report(pages: [create_page(url: "http://example.com/page#{i}")])
        File.write(file_path, JSON.pretty_generate(report))
        file_path
      end
    end
  end
end
