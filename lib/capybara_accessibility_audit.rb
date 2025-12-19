require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.setup

module CapybaraAccessibilityAudit
  extend self

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
