require "axe/api/context"
require "axe/api/options"
require "axe/api/results"
require "axe/configuration"

module CapybaraAccessibilityAudit
  class AxeAuditor
    Error = Class.new(StandardError)

    ERROR_KEY = "capybara_accessibility_audit_error"

    class_attribute :source, instance_accessor: false, default: Axe::Configuration.instance.jslib

    class_attribute :quiet_period_ms, instance_accessor: false, default: 100
    class_attribute :quiet_period_timeout_ms, instance_accessor: false, default: 2000

    def initialize(test, reporter)
      @test = test
      @reporter = reporter
    end

    def audit(**options)
      settle
      install

      results = run(options).then { |results| denullify(results) }

      @reporter.report Axe::API::Results.new(results)
    end

    private

    def page
      @test.page
    end

    def settle
      quiet_period_ms = self.class.quiet_period_ms
      earliest = monotonic_time + quiet_period_ms
      deadline = monotonic_time + self.class.quiet_period_timeout_ms

      observe_mutations

      until monotonic_time >= deadline
        if (duration = unchanged_for).nil?
          observe_mutations
        elsif monotonic_time >= earliest && duration >= quiet_period_ms
          break
        end

        sleep 0.01
      end
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    end

    # Records the time of the last change to the DOM. The document keeps the
    # observer that is already there.
    def observe_mutations
      page.execute_script <<~JS
        if (!window.capybaraAccessibilityAudit) {
          window.capybaraAccessibilityAudit = {changedAt: Date.now()}

          new MutationObserver(() => {
            window.capybaraAccessibilityAudit.changedAt = Date.now()
          }).observe(document, {attributes: true, characterData: true, childList: true, subtree: true})
        }
      JS
    end

    # Answers how long the DOM has been unchanged, in milliseconds. Answers
    # nil when a page load replaced the document that has the observer. Each
    # call is a short round trip. A single long-lived script would lose its
    # callback when a page load discards the document it runs in.
    def unchanged_for
      duration = page.evaluate_script <<~JS
        window.capybaraAccessibilityAudit ? Date.now() - window.capybaraAccessibilityAudit.changedAt : null
      JS

      duration if duration.is_a?(Numeric) # :playwright returns null as {}
    end

    def run(config)
      context, options = split(config)

      results = page.evaluate_async_script <<~JS, context.as_json, options.as_json, ERROR_KEY
        const [ context, options, errorKey, callback ] = arguments

        axe.run(context, options).then(callback).catch(error => callback({ [errorKey]: error.message }))
      JS

      if (message = results[ERROR_KEY])
        raise Error, message
      else
        results
      end
    end

    def split(config)
      context = Axe::API::Context.new
      options = Axe::API::Options.new

      config.each do |name, value|
        case name
        when :within, :excluding then context.public_send(name, value)
        else options.public_send(name, value)
        end
      end

      [context, options]
    end

    def install
      page.execute_script(self.class.source) unless installed?
    end

    def installed?
      page.evaluate_script <<~JS
        "axe" in window && typeof axe.run === "function"
      JS
    end

    def denullify(value)
      case value
      when Hash
        value.transform_values { |nested| denullify(nested) } unless value.empty?
      when Array
        value.map { |nested| denullify(nested) }
      else
        value
      end
    end
  end
end
