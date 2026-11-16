module CapybaraAccessibilityAudit
  # Records the violations each test detects in the todo file, rather than
  # reporting them. The first audit in a test replaces what the file lists for
  # that test, so a run removes the entries for violations that were fixed and
  # keeps the entries for tests that did not run.
  class TodoReporter
    def initialize(test, todo_list)
      @test = test
      @todo_list = todo_list
      @recorded = false
    end

    def report(results)
      @todo_list.record(TodoList.identify(@test), results.violations, replace: !@recorded)
      @recorded = true
    end
  end
end
