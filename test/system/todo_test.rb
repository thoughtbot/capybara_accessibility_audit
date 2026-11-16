require "application_system_test_case"

module CapybaraAccessibilityAudit
  class TodoTestCase < ApplicationSystemTestCase
    setup do
      @todo_directory = Dir.mktmpdir
      @todo_file = Pathname(@todo_directory).join(".capybara_accessibility_audit_todo.yml")
    end

    teardown do
      FileUtils.remove_entry(@todo_directory)
    end

    def use_todo_file(generate:, entries: nil)
      @todo_file.write(YAML.dump(entries)) if entries

      self.accessibility_audit_todo_file = @todo_file
      self.accessibility_audit_generate_todo = generate
      self.accessibility_audit_auditor = AxeAuditor.new(self, CapybaraAccessibilityAudit.reporter_for(self))
    end

    def todo_entries
      YAML.safe_load(@todo_file.read)
    end

    def current_test_id
      TodoList.identify(self)
    end
  end

  class TodoReporterTest < TodoTestCase
    test "records violations instead of raising them" do
      use_todo_file generate: true

      visit violations_path(rules: %w[label image-alt])

      assert_equal({current_test_id => {"image-alt" => ["img"], "label" => ["input"]}}, todo_entries)
      assert_match(/\A# This file lists the accessibility violations/, @todo_file.read)
    end

    test "merges the violations from each audit within a test" do
      use_todo_file generate: true

      visit violations_path(rules: %w[label])
      visit violations_path(rules: %w[image-alt])
      visit violations_path(rules: %w[label])

      assert_equal({current_test_id => {"image-alt" => ["img"], "label" => ["input"]}}, todo_entries)
    end

    test "replaces the test's entry and keeps the entries of other tests" do
      use_todo_file generate: true, entries: {
        "OtherTest#test_other" => {"label" => ["input"]},
        current_test_id => {"button-name" => ["button"]}
      }

      visit violations_path(rules: %w[image-alt])

      assert_equal(
        {"OtherTest#test_other" => {"label" => ["input"]}, current_test_id => {"image-alt" => ["img"]}},
        todo_entries
      )
    end

    test "removes the test's entry when the test detects no violations" do
      use_todo_file generate: true, entries: {current_test_id => {"label" => ["input"]}}

      visit violations_path

      assert_equal({}, todo_entries)
    end
  end

  class TodoFilterTest < TodoTestCase
    test "raises violations when the todo file does not exist" do
      use_todo_file generate: false

      assert_rule_violation "label: Form elements must have labels" do
        visit violations_path(rules: %w[label])
      end
      assert_not @todo_file.exist?
    end

    test "ignores the violations that the todo file permits for the test" do
      use_todo_file generate: false, entries: {current_test_id => {"label" => ["input"]}}

      visit violations_path(rules: %w[label])
    end

    test "ignores every node when the todo file permits the rule without selectors" do
      use_todo_file generate: false, entries: {current_test_id => {"label" => nil}}

      visit violations_path(rules: %w[label])
    end

    test "raises the violations that the todo file does not permit" do
      use_todo_file generate: false, entries: {current_test_id => {"label" => ["input"]}}

      assert_rule_violation with: "image-alt: Images must have alternative text", without: "label:" do
        visit violations_path(rules: %w[label image-alt])
      end
    end

    test "raises violations of a permitted rule for nodes that the todo file does not list" do
      use_todo_file generate: false, entries: {current_test_id => {"label" => ["#another-input"]}}

      assert_rule_violation "label: Form elements must have labels" do
        visit violations_path(rules: %w[label])
      end
    end

    test "raises the violations that the todo file permits for another test" do
      use_todo_file generate: false, entries: {"OtherTest#test_other" => {"label" => ["input"]}}

      assert_rule_violation "label: Form elements must have labels" do
        visit violations_path(rules: %w[label])
      end
    end

    test "regenerating the file permits the violations it recorded" do
      use_todo_file generate: true
      visit violations_path(rules: %w[label image-alt])

      use_todo_file generate: false
      visit violations_path(rules: %w[label image-alt])
    end
  end
end
