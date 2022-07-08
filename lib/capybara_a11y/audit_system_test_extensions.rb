require "axe-capybara"
require "axe/matchers/be_axe_clean"

module CapybaraA11y
  module AuditSystemTestExtensions
    extend ActiveSupport::Concern

    included do
      class_attribute :accessibility_audit_after_methods, default: Set.new
      class_attribute :accessibility_audit_enabled, default: true
      class_attribute :accessibility_audit_options, default: ActiveSupport::OrderedOptions.new
    end

    class_methods do
      def inherited(descendant)
        super

        descendant.accessibility_audit_options = accessibility_audit_options.deep_dup
      end

      def accessibility_audit_after(*methods)
        (methods.flatten.to_set - accessibility_audit_after_methods).each do |method|
          define_method method do |*arguments, **options, &block|
            super(*arguments, **options, &block).tap { audit! method }
          end

          accessibility_audit_after_methods << method
        end

      end
    end

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

      assert axe_matcher.matches?(page), axe_matcher.failure_message
    end

    private

    def audit!(method)
      if accessibility_audit_enabled && method.in?(accessibility_audit_after_methods)
        assert_no_accessibility_violations(**accessibility_audit_options)
      end
    end
  end
end
