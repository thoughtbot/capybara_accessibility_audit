module CapybaraAccessibilityAudit
  # Removes the violations that the todo file permits for the test, then hands
  # the results to the reporter. The reporter receives the violations that the
  # file does not list.
  class TodoFilter
    def initialize(test, todo_list, reporter)
      @test = test
      @todo_list = todo_list
      @reporter = reporter
    end

    def report(results)
      if results.violations.any?
        results = @todo_list.reject_permitted(TodoList.identify(@test), results)
      end

      @reporter.report(results)
    end
  end
end
