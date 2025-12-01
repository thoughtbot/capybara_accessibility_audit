namespace :capybara_accessibility_audit do
  desc "Merge multiple JSON accessibility audit reports into a single report"
  task :merge, [:output, :pattern] => :environment do |_t, args|
    require "capybara_accessibility_audit/report_merger"

    unless args[:output]
      puts "Error: output path is required"
      puts "Usage: rake capybara_accessibility_audit:merge[output.json,reports/*.json]"
      exit 1
    end

    pattern = args[:pattern] || "tmp/accessibility_reports/*.json"
    report_files = Dir.glob(pattern)

    if report_files.empty?
      puts "Error: No report files found matching pattern: #{pattern}"
      exit 1
    end

    puts "Merging #{report_files.count} report#{"s" if report_files.count != 1}:"
    report_files.each { |f| puts "  - #{f}" }

    begin
      merged = CapybaraAccessibilityAudit::ReportMerger.merge(
        report_paths: report_files,
        output_path: args[:output]
      )

      puts "\nMerge complete!"
      puts "  Total violations: #{merged[:summary][:total_violations]}"
      puts "  Pages with violations: #{merged[:summary][:num_pages_with_violations]}"
      puts "  Violations by impact:"
      merged[:summary][:num_violations_by_impact].each do |impact, count|
        puts "    #{impact}: #{count}"
      end
    rescue => e
      puts "\nError merging reports: #{e.message}"
      puts e.backtrace.first(5).map { |line| "  #{line}" } if ENV["DEBUG"]
      exit 1
    end
  end
end
