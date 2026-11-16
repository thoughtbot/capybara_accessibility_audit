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

  def reporter_for(test)
    reporter = reporter_class(test.accessibility_audit_reporter).new(test)

    if (path = test.accessibility_audit_todo_file)
      todo_list = TodoList.new(path)

      if test.accessibility_audit_generate_todo
        TodoReporter.new(test, todo_list)
      else
        TodoFilter.new(test, todo_list, reporter)
      end
    else
      reporter
    end
  end
end

loader.eager_load
