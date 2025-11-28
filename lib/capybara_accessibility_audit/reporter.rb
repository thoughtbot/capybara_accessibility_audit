# frozen_string_literal: true

require "json"
require "fileutils"

module CapybaraAccessibilityAudit
  class Reporter
    class << self
      def violations
        @violations ||= []
      end

      def add_violation(url:, audit:, timestamp: Time.now)
        # Extract structured data from the audit object
        violation_data = {
          url: url,
          timestamp: timestamp.iso8601,
          violations: audit.results.violations.map { |v| violation_to_hash(v) },
          test_engine: audit.results.testEngine,
          test_environment: audit.results.testEnvironment
        }

        violations << violation_data
      end

      def clear!
        @violations = []
      end

      def report_to_stdout!
        return if violations.empty?

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

      def report_to_json!(file_path)
        FileUtils.mkdir_p(File.dirname(file_path))

        File.write(file_path, JSON.pretty_generate(summary_data))

        puts "\n======> Accessibility audit report written to: #{file_path}"
      end

      def report!
        return if violations.empty?

        if report_file_path
          report_to_json!(report_file_path)
        else
          report_to_stdout!
        end
      end

      attr_writer :report_file_path

      attr_reader :report_file_path

      private

      def violation_to_hash(rule)
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

      def node_to_hash(node)
        {
          html: node.html,
          target: node.target,
          failureSummary: node.failureSummary,
          impact: node.impact
        }
      end

      def total_violation_count
        violations.sum { |page_data| page_data[:violations].count }
      end

      def summary_data
        {
          summary: {
            total_violations: total_violation_count,
            pages_with_violations: violations.count,
            generated_at: Time.now.iso8601
          },
          violations_by_page: violations,
          violations_by_rule: group_violations_by_rule
        }
      end

      def group_violations_by_rule
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
              tags: violation[:tags],
              occurrences: 0,
              pages: []
            }
            rule_details[rule_id][:occurrences] += violation[:nodes].count
            rule_details[rule_id][:pages] << page_data[:url] unless rule_details[rule_id][:pages].include?(page_data[:url])
          end
        end

        rule_details.sort_by { |_id, data| -data[:occurrences] }.to_h
      end
    end
  end
end
