require "test_helper"

module CapybaraAccessibilityAudit
  class TodoListTest < ActiveSupport::TestCase
    test "permits the selectors that the list includes for the test and rule" do
      list = todo_list("Test#test_a" => {"label" => ["input"], "image-alt" => nil})

      assert list.permitted?("Test#test_a", :label, node("input"))
      assert list.permitted?("Test#test_a", :"image-alt", node("img.hero"))
      assert_not list.permitted?("Test#test_a", :label, node("#other"))
      assert_not list.permitted?("Test#test_a", :"button-name", node("button"))
      assert_not list.permitted?("Test#test_b", :label, node("input"))
    end

    test "compares selectors for nodes within frames and shadow roots" do
      list = todo_list("Test#test_a" => {"label" => ["iframe, input"]})

      assert list.permitted?("Test#test_a", :label, node(["iframe", "input"]))
    end

    test "rejects the permitted violations from results" do
      list = todo_list("Test#test_a" => {"label" => ["input"]})
      results = Axe::API::Results.new(violations: [
        {id: "label", help: "Form elements must have labels", nodes: [{target: ["input"]}, {target: ["#other"]}]},
        {id: "image-alt", help: "Images must have alternative text", nodes: [{target: ["img"]}]}
      ])

      filtered = list.reject_permitted("Test#test_a", results)

      assert_equal [:label, :"image-alt"], filtered.violations.map(&:id)
      assert_equal [["#other"]], filtered.violations.first.nodes.map(&:target)
      assert_equal 2, results.violations.first.nodes.size, "does not modify the original results"
    end

    test "serializes concurrent writes from multiple processes" do
      Dir.mktmpdir do |directory|
        path = Pathname(directory).join("todo.yml")
        rule = Axe::API::Results::Rule.new(id: "label", nodes: [{target: ["input"]}])

        pids = 8.times.map do |index|
          fork do
            TodoList.new(path).record("Test#test_#{index}", [rule], replace: true)
            exit!(true)
          end
        end
        pids.each { |pid| Process.wait(pid) }

        assert_equal 8, TodoList.new(path).entries.size
      end
    end

    private

    def todo_list(entries)
      file = Tempfile.new(["todo", ".yml"])
      file.write(YAML.dump(entries))
      file.close

      TodoList.new(file.path)
    end

    def node(target)
      Axe::API::Results::Node.new(target: Array(target))
    end
  end
end
