require "axe/api/context"
require "axe/api/options"
require "axe/api/results"
require "axe/configuration"

module CapybaraAccessibilityAudit
  class AxeAuditor
    class_attribute :source, instance_accessor: false, default: Axe::Configuration.instance.jslib

    def initialize(page, reporter)
      @page_proc = page.is_a?(Proc) ? page : -> { page }
      @reporter = reporter
    end

    def audit(**options)
      install

      results = run(options)

      @reporter.report Axe::API::Results.new(results)
    end

    private

    def page
      @page_proc.call
    end

    def run(config)
      context, options = split(config)

      page.evaluate_async_script <<~JS, context.to_h, options.to_h
        const [ context, options, callback ] = arguments

        axe.run(context, options).then(callback)
      JS
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
  end
end
