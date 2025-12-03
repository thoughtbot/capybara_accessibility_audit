# frozen_string_literal: true

require "json"
require "fileutils"

module CapybaraAccessibilityAudit
  class Reporter
    IMPACT_PRIORITY = {
      "critical" => 4,
      "serious" => 3,
      "moderate" => 2,
      "minor" => 1
    }

    def self.violations
      @violations ||= []
    end

    def self.add_violation(url:, audit:, timestamp: Time.now)
      violation_data = {
        url: url,
        timestamp: timestamp.iso8601,
        violations: audit.results.violations.map { |v| violation_to_hash(v) },
        test_engine: audit.results.testEngine,
        test_environment: audit.results.testEnvironment
      }

      violations << violation_data
    end

    def self.clear!
      @violations = []
    end

    def self.report_to_stdout!
      puts "\n" + "=" * 80
      puts "ACCESSIBILITY AUDIT REPORT"
      puts "=" * 80
      puts "Total violations found: #{total_violation_count}"
      puts "Pages with violations: #{violations.count}"
      puts "=" * 80

      violations.each_with_index do |page_data, idx|
        puts "\n#{idx + 1}. URL: #{page_data[:url]}"
        puts "   Time: #{page_data[:timestamp]}"
        puts "   Violations: #{page_data[:violations].count}"

        page_data[:violations].each do |violation|
          puts "\n   - [#{violation[:impact].upcase}] #{violation[:id]}"
          puts "     #{violation[:help]}"
          puts "     #{violation[:helpUrl]}"
          puts "     Affected elements: #{violation[:nodes].count}"
          puts "     Tags: #{violation[:tags].join(", ")}"
        end
        puts "   " + "-" * 76
      end

      puts "=" * 80 + "\n"
    end

    def self.report_to_json!(file_path)
      FileUtils.mkdir_p(File.dirname(file_path))

      File.write(file_path, JSON.pretty_generate(summary_data))

      puts "\n======> Accessibility audit report written to: #{file_path}"
    end

    def self.report!
      if report_file_path
        report_to_json!(report_file_path)
      else
        report_to_stdout!
      end
    end

    class << self
      attr_accessor :report_file_path
    end

    private_class_method def self.violation_to_hash(rule)
      {
        id: rule.id,
        impact: rule.impact,
        description: rule.description,
        help: rule.help,
        helpUrl: rule.helpUrl,
        tags: rule.tags,
        nodes: rule.nodes.map { |node| node_to_hash(node) }
      }
    end

    private_class_method def self.node_to_hash(node)
      {
        html: node.html,
        target: node.target,
        failureSummary: node.failureSummary,
        impact: node.impact
      }
    end

    private_class_method def self.total_violation_count
      violations.sum { |page_data| page_data[:violations].count }
    end

    private_class_method def self.summary_data
      {
        summary: {
          total_violations: total_violation_count,
          num_pages_with_violations: violations.count,
          num_violations_by_impact: num_violations_by_impact,
          generated_at: Time.now.iso8601
        },
        violations_by_rule: group_violations_by_rule,
        violations_by_page: violations
      }
    end

    private_class_method def self.num_violations_by_impact
      impact_counts = Hash.new(0)

      violations.each do |page_data|
        page_data[:violations].each do |violation|
          impact = violation[:impact].to_s
          impact_counts[impact] += violation[:nodes].count
        end
      end

      IMPACT_PRIORITY.keys.sort_by { |impact| -IMPACT_PRIORITY[impact] }.each_with_object({}) do |impact, result|
        result[impact] = impact_counts[impact]
      end
    end

    private_class_method def self.group_violations_by_rule
      rule_counts = Hash.new(0)
      rule_details = {}

      violations.each do |page_data|
        page_data[:violations].each do |violation|
          rule_id = violation[:id]
          rule_counts[rule_id] += violation[:nodes].count
          rule_details[rule_id] ||= {
            impact: violation[:impact],
            description: violation[:description],
            help: violation[:help],
            helpUrl: violation[:helpUrl],
            tags: violation[:tags]&.sort || [],
            num_occurrences: 0,
            pages: []
          }
          rule_details[rule_id][:num_occurrences] += violation[:nodes].count
          rule_details[rule_id][:pages] << page_data[:url] unless rule_details[rule_id][:pages].include?(page_data[:url])
        end
      end

      rule_details.each do |_rule_id, data|
        data[:pages].sort!
      end

      rule_details.sort_by do |_id, data|
        [
          -IMPACT_PRIORITY.fetch(data[:impact].to_s, 0),
          -data[:num_occurrences]
        ]
      end.to_h
    end
  end
end
