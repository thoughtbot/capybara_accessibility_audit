require "spec_helper"

RSpec.describe "Audit assertions", type: :system do
  before { driven_by Capybara.javascript_driver }

  it "audits with the session that is current when the audit runs" do
    assert_rule_violation "label: Form elements must have labels" do
      visit violations_path(rules: %w[label])
    end
  end
end
