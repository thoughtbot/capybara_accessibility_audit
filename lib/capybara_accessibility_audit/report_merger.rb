# frozen_string_literal: true

require "json"
require "fileutils"

module CapybaraAccessibilityAudit
  class ReportMerger
    def self.merge(report_paths:, output_path:)
      new(report_paths: report_paths, output_path: output_path).merge
    end

    def self.merge_data(reports)
      new.merge_data(reports)
    end

    def initialize(report_paths: [], output_path: nil)
      @report_paths = Array(report_paths)
      @output_path = output_path
    end

    def merge
      validate_inputs!
      reports = load_reports
      merged = merge_data(reports)
      write_output(merged) if @output_path
      merged
    end

    def merge_data(reports)
      return empty_report if reports.empty?

      violations_by_page = merge_violations_by_page(reports)
      violations_by_rule = merge_violations_by_rule(reports)

      {
        summary: calculate_summary(violations_by_page, reports),
        violations_by_page: violations_by_page,
        violations_by_rule: violations_by_rule
      }
    end

    private

    IMPACT_PRIORITY = Reporter::IMPACT_PRIORITY

    def validate_inputs!
      raise ArgumentError, "No report paths provided" if @report_paths.empty?

      @report_paths.each do |path|
        raise ArgumentError, "File not found: #{path}" unless File.exist?(path)
      end
    end

    def load_reports
      @report_paths.map do |path|
        JSON.parse(File.read(path), symbolize_names: true)
      rescue JSON::ParserError => e
        raise JSON::ParserError, "Invalid JSON in #{path}: #{e.message}"
      end
    end

    def write_output(merged_data)
      FileUtils.mkdir_p(File.dirname(@output_path))
      File.write(@output_path, JSON.pretty_generate(merged_data))
      puts "\nMerged report written to: #{@output_path}"
    end

    def empty_report
      {
        summary: {
          total_violations: 0,
          num_pages_with_violations: 0,
          violations_by_impact: IMPACT_PRIORITY.keys.sort_by { |k| -IMPACT_PRIORITY[k] }.each_with_object({}) { |k, h| h[k] = 0 },
          generated_at: Time.now.iso8601
        },
        violations_by_page: [],
        violations_by_rule: {}
      }
    end

    def merge_violations_by_page(reports)
      pages_by_url = {}

      reports.each do |report|
        report[:violations_by_page].each do |page_data|
          url = page_data[:url]

          pages_by_url[url] = if pages_by_url[url]
            merge_page_data(pages_by_url[url], page_data)
          else
            deep_dup(page_data)
          end
        end
      end

      pages_by_url.values.sort_by { |page| page[:url] }
    end

    def merge_page_data(existing_page, new_page)
      {
        url: existing_page[:url],
        timestamp: [existing_page[:timestamp], new_page[:timestamp]].max,
        violations: merge_violations(existing_page[:violations], new_page[:violations]),
        test_engine: new_page[:test_engine] || existing_page[:test_engine],
        test_environment: new_page[:test_environment] || existing_page[:test_environment]
      }
    end

    def merge_violations(violations1, violations2)
      violations_by_id = {}

      (violations1 + violations2).each do |violation|
        rule_id = violation[:id]

        if violations_by_id[rule_id]
          violations_by_id[rule_id][:nodes] += violation[:nodes]
          violations_by_id[rule_id][:nodes].uniq! { |node| node[:target] }
        else
          violations_by_id[rule_id] = deep_dup(violation)
        end
      end

      violations_by_id.values.sort_by do |v|
        [-IMPACT_PRIORITY.fetch(v[:impact].to_s, 0), v[:id]]
      end
    end

    def merge_violations_by_rule(reports)
      rules = {}

      reports.each do |report|
        report[:violations_by_rule].each do |rule_id, rule_data|
          if rules[rule_id]
            rules[rule_id][:num_occurrences] += rule_data[:num_occurrences]
            rules[rule_id][:pages] = (rules[rule_id][:pages] + rule_data[:pages]).uniq
          else
            rules[rule_id] = {
              impact: rule_data[:impact],
              description: rule_data[:description],
              help: rule_data[:help],
              helpUrl: rule_data[:helpUrl],
              tags: rule_data[:tags],
              num_occurrences: rule_data[:num_occurrences],
              pages: rule_data[:pages].dup
            }
          end
        end
      end

      rules.sort_by do |_rule_id, data|
        [
          -IMPACT_PRIORITY.fetch(data[:impact].to_s, 0),
          -data[:num_occurrences]
        ]
      end.to_h
    end

    def calculate_summary(violations_by_page, reports)
      {
        total_violations: calculate_total_violations(violations_by_page),
        num_pages_with_violations: count_pages_with_violations(violations_by_page),
        violations_by_impact: calculate_violations_by_impact(violations_by_page),
        generated_at: latest_timestamp(reports)
      }
    end

    def calculate_total_violations(violations_by_page)
      violations_by_page.sum do |page_data|
        page_data[:violations].sum { |v| v[:nodes].count }
      end
    end

    def count_pages_with_violations(violations_by_page)
      violations_by_page.count { |page| page[:violations].any? }
    end

    def calculate_violations_by_impact(violations_by_page)
      impact_counts = Hash.new(0)

      violations_by_page.each do |page_data|
        page_data[:violations].each do |violation|
          impact = violation[:impact].to_s
          impact_counts[impact] += violation[:nodes].count
        end
      end

      IMPACT_PRIORITY.keys.sort_by { |impact| -IMPACT_PRIORITY[impact] }.each_with_object({}) do |impact, result|
        result[impact] = impact_counts[impact]
      end
    end

    def latest_timestamp(reports)
      reports.map { |r| r.dig(:summary, :generated_at) }
        .compact
        .max || Time.now.iso8601
    end

    def deep_dup(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
      when Array
        obj.map { |v| deep_dup(v) }
      else
        begin
          obj.dup
        rescue
          obj
        end
      end
    end
  end
end
