# frozen_string_literal: true

module CapybaraAccessibilityAudit
  class ReportMode
    # Base class for report modes
    def enabled?
      true
    end

    def report?
      false
    end

    def assert?
      !report?
    end

    def handle_violations(audit:, url:)
      raise NotImplementedError
    end

    # Factory method to create mode from config
    # Supports backwards compatibility with accessibility_audit_enabled:
    #   false -> Disabled (backwards compatible with accessibility_audit_enabled = false)
    #   true -> Assert (backwards compatible with accessibility_audit_enabled = true)
    #   :assert -> Assert (new: explicit assert mode)
    #   :stdout -> StdoutReporter (new: report to stdout)
    #   { file: 'path' } -> FileReporter (new: report to JSON file)
    def self.from_config(mode_config)
      case mode_config
      when false # Backwards compatibility: accessibility_audit_enabled = false
        Disabled.new
      when true # Backwards compatibility: accessibility_audit_enabled = true
        Assert.new
      when :assert
        Assert.new
      when :stdout
        StdoutReporter.new
      when Hash
        if mode_config[:file]
          FileReporter.new(mode_config[:file])
        else
          raise ArgumentError, "Invalid report mode configuration: #{mode_config.inspect}"
        end
      else
        raise ArgumentError, "Invalid report mode: #{mode_config.inspect}. Expected false, true, :assert, :stdout, or { file: 'path' }"
      end
    end

    # Disabled mode - audits don't run at all
    # Used for backwards compatibility when accessibility_audit_enabled = false
    class Disabled < ReportMode
      def enabled?
        false
      end

      def handle_violations(audit:, url:)
        raise "Impossible state: handle_violations called on Disabled mode. Audits should not run when disabled."
      end
    end

    # Assert mode - fails tests on violations (default behavior)
    class Assert < ReportMode
      def assert?
        true
      end

      def handle_violations(audit:, url:)
        # Return the failure message to be used in assert
        audit.failure_message
      end
    end

    # Stdout mode - logs violations to stdout, doesn't fail tests
    class StdoutReporter < ReportMode
      def report?
        true
      end

      def handle_violations(audit:, url:)
        Reporter.add_violation(url: url, audit: audit)
        nil # Don't fail the test
      end
    end

    # File mode - logs violations to JSON file, doesn't fail tests
    class FileReporter < ReportMode
      attr_reader :file_path

      def initialize(file_path)
        @file_path = file_path
        Reporter.report_file_path = file_path
      end

      def report?
        true
      end

      def handle_violations(audit:, url:)
        Reporter.add_violation(url: url, audit: audit)
        nil # Don't fail the test
      end
    end
  end
end
