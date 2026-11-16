require "spec_helper"

RSpec.describe "Todo file", type: :system, js: true do
  before :all do
    driven_by Capybara.javascript_driver
  end

  around do |example|
    Dir.mktmpdir do |directory|
      @todo_file = Pathname(directory).join(".capybara_accessibility_audit_todo.yml")
      example.run
    end
  end

  def use_todo_file(generate:, entries: nil)
    @todo_file.write(YAML.dump(entries)) if entries

    self.accessibility_audit_todo_file = @todo_file
    self.accessibility_audit_generate_todo = generate
    self.accessibility_audit_auditor = CapybaraAccessibilityAudit::AxeAuditor.new(self, CapybaraAccessibilityAudit.reporter_for(self))
  end

  it "records violations under the example's full description" do
    use_todo_file generate: true

    visit violations_path(rules: %w[label])

    expect(YAML.safe_load(@todo_file.read)).to eq(
      "Todo file records violations under the example's full description" => {"label" => ["input"]}
    )
  end

  it "ignores the violations that the todo file permits for the example" do
    use_todo_file generate: false, entries: {
      "Todo file ignores the violations that the todo file permits for the example" => {"label" => ["input"]}
    }

    visit violations_path(rules: %w[label])
  end

  it "raises the violations that the todo file does not permit" do
    use_todo_file generate: false, entries: {"Another example" => {"label" => ["input"]}}

    assert_rule_violation "label: Form elements must have labels" do
      visit violations_path(rules: %w[label])
    end
  end
end
