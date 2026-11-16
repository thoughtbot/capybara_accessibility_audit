require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.setup

module CapybaraAccessibilityAudit
  extend self

  # Before config.capybara_accessibility_audit.auditor held options, it held
  # the auditor class. Keep honoring a class assigned there.
  def auditor_class(config)
    config.is_a?(::Class) ? config : AxeAuditor
  end

  def reporter_class(name)
    case name
    when :notification, :log
      NotificationReporter
    when :raise
      RaiseReporter
    when ::Class
      name
    else
      raise ArgumentError.new("unsupported reporter: #{name}")
    end
  end
end

loader.eager_load
