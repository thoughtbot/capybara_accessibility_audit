require "axe/matchers/be_axe_clean"
require_relative "report_mode"
require_relative "reporter"

module CapybaraAccessibilityAudit
  module AuditSystemTestExtensions
    extend ActiveSupport::Concern

    MODAL_METHODS =
      if defined?(Capybara::Session::MODAL_METHODS)
        Capybara::Session::MODAL_METHODS
      else
        %i[accept_alert accept_confirm accept_prompt dismiss_confirm dismiss_prompt]
      end

    included do
      class_attribute :accessibility_audit_after_methods, default: Set.new
      class_attribute :accessibility_audit_options, default: ActiveSupport::OrderedOptions.new

      # Store the actual value internally
      class_attribute :_accessibility_audit_enabled_value, default: true

      # Internal accessor for report mode - converts accessibility_audit_enabled to ReportMode
      def self.accessibility_audit_report_mode
        @accessibility_audit_report_mode ||= ReportMode.from_config(_accessibility_audit_enabled_value)
      end

      def self.accessibility_audit_report_mode=(mode)
        @accessibility_audit_report_mode = mode.is_a?(ReportMode) ? mode : ReportMode.from_config(mode)
      end

      def accessibility_audit_report_mode
        self.class.accessibility_audit_report_mode
      end

      def accessibility_audit_report_mode=(mode)
        self.class.accessibility_audit_report_mode = mode
      end

      # Public accessors for backwards compatibility
      def self.accessibility_audit_enabled=(value)
        @accessibility_audit_report_mode = nil  # Clear cache
        self._accessibility_audit_enabled_value = value
      end

      def self.accessibility_audit_enabled
        accessibility_audit_report_mode.enabled?
      end

      def accessibility_audit_enabled=(value)
        self.class.accessibility_audit_enabled = value
      end

      def accessibility_audit_enabled
        self.class.accessibility_audit_enabled
      end

      MODAL_METHODS.each do |method|
        define_method method do |*arguments, **options, &block|
          result = super(*arguments, **options) { skip_accessibility_audits(&block) }
          result.tap { Auditor.new(self).audit!(method) }
        end
      end
    end

    class_methods do
      def inherited(descendant)
        super

        descendant.accessibility_audit_options = accessibility_audit_options.deep_dup
        descendant.accessibility_audit_after_methods = accessibility_audit_after_methods.dup
      end

      def accessibility_audit_after(*methods)
        (methods.flatten.to_set - accessibility_audit_after_methods).each do |method|
          define_method method do |*arguments, **options, &block|
            super(*arguments, **options, &block).tap { Auditor.new(self).audit!(method) }
          end

          accessibility_audit_after_methods << method
        end
      end

      def skip_accessibility_audit_after(*methods)
        methods.each { |method| accessibility_audit_after_methods.delete(method) }
      end
    end

    delegate :accessibility_audit_after, :skip_accessibility_audit_after, to: :class

    def with_accessibility_audits(**options, &block)
      accessibility_audit_enabled = self.accessibility_audit_enabled
      self.accessibility_audit_enabled = true

      if options.present?
        with_accessibility_audit_options(**options, &block)
      else
        block.call
      end
    ensure
      self.accessibility_audit_enabled = accessibility_audit_enabled
    end

    def with_accessibility_audit_options(**options, &block)
      accessibility_audit_options = self.accessibility_audit_options
      self.accessibility_audit_options = accessibility_audit_options.merge(options)

      block.call
    ensure
      self.accessibility_audit_options = accessibility_audit_options
    end

    def skip_accessibility_audits(&block)
      accessibility_audit_enabled = self.accessibility_audit_enabled
      self.accessibility_audit_enabled = false

      block.call
    ensure
      self.accessibility_audit_enabled = accessibility_audit_enabled
    end

    def skip_accessibility_violations(value, &block)
      skipping = accessibility_audit_options.skipping
      accessibility_audit_options.skipping = Array(value)

      block.call
    ensure
      accessibility_audit_options.skipping = skipping
    end

    def assert_no_accessibility_violations(**options)
      options.assert_valid_keys(
        :according_to,
        :checking,
        :checking_only,
        :excluding,
        :skipping,
        :within
      )
      options.compact_blank!

      axe_matcher = Axe::Matchers::BeAxeClean.new
      axe_matcher = options.inject(axe_matcher) { |matcher, option| matcher.public_send(*option) }

      # Run the audit to get structured results
      audit = axe_matcher.audit(page)

      # If audit passed, nothing to do
      return if audit.passed?

      # When assert_no_accessibility_violations is called explicitly, always assert
      # (ignore the global report mode setting)
      # This ensures manual assertions always fail tests, even if auto-audits are disabled
      failure_message = ReportMode::Assert.new.handle_violations(
        audit: audit,
        url: page.current_url
      )

      assert false, failure_message
    end

    # Used by Auditor for automatic audits - respects the report mode setting
    def audit_with_report_mode(**options)
      options.assert_valid_keys(
        :according_to,
        :checking,
        :checking_only,
        :excluding,
        :skipping,
        :within
      )
      options.compact_blank!

      axe_matcher = Axe::Matchers::BeAxeClean.new
      axe_matcher = options.inject(axe_matcher) { |matcher, option| matcher.public_send(*option) }

      # Run the audit to get structured results
      audit = axe_matcher.audit(page)

      # If audit passed, nothing to do
      return if audit.passed?

      # Use the configured report mode for automatic audits
      failure_message = accessibility_audit_report_mode.handle_violations(
        audit: audit,
        url: page.current_url
      )

      # Only assert if we're in assert mode (failure_message will be nil for report modes)
      assert false, failure_message if failure_message
    end
  end
end
