require "spec_helper"

RSpec.describe "Audit assertions", type: ENV.fetch("RSPEC_TYPE", "system") do
  before do
    driven_by :selenium_headless, using: :headless_chrome, screen_size: [1400, 1400]
  end

  it "flunks on violations detected after #visit" do
    assert_rule_violation "label: Form elements must have labels" do
      visit violations_path(rules: %w[label])
    end
  end

  it "flunks on violations detected after #click_on" do
    visit violations_path

    assert_rule_violation "label: Form elements must have labels" do
      click_on "Violate rule: label"
    end
  end

  it "flunks on violations detected after #click_link" do
    visit violations_path

    assert_rule_violation "label: Form elements must have labels" do
      click_link "Violate rule: label"
    end
  end

  it "flunks on violations detected after #click_button" do
    visit violations_path
    fill_in "Rules to violate", with: "label"

    assert_rule_violation "label: Form elements must have labels" do
      click_button "Submit"
    end
  end

  it "flunks on violations detected after #click_link_or_button" do
    visit violations_path

    assert_rule_violation "label: Form elements must have labels" do
      click_link_or_button "Violate rule: label"
    end
  end

  it "ignores violations within a matching skip_accessibility_violations block" do
    skip_accessibility_violations("label") { visit violations_path(rules: %w[label]) }
    skip_accessibility_violations(%w[label]) { visit violations_path(rules: %w[label]) }
  end

  it "raises violations within a skip_accessibility_violation block that does not apply" do
    skip_accessibility_violations "label" do
      assert_rule_violation "image-alt: Images must have alternative text" do
        visit violations_path(rules: %w[image-alt])
      end
    end
  end

  it "ignores violations when wrapped in skip_accessibility_audits" do
    skip_accessibility_audits do
      visit violations_path(rules: %w[label])
    end
  end

  describe "Make failing tests Pending" do
    before do
      self.accessibility_audit_skip_on_error = true
    end

    it "marks violation test as pending" do
      allow_any_instance_of(RSpec::Core::Pending).to receive(:skip)
      visit violations_path
      click_on "Violate rule: label"
      go_back
      click_on "Violate rule: image-alt"
    end
  end

  describe "Disabling" do
    before do
      self.accessibility_audit_enabled = false
    end

    it "ignores violations" do
      visit violations_path
      click_on "Violate rule: label"
      go_back
      click_on "Violate rule: image-alt"
    end

    it "flunks on calls within with_accessibility_audits" do
      with_accessibility_audits do
        assert_rule_violation "label: Form elements must have labels" do
          visit violations_path(rules: %w[label])
        end
      end
    end

    it "flunks on calls within with_accessibility_audits based on options" do
      visit violations_path

      with_accessibility_audits skipping: "label" do
        click_on "Violate rule: label"
      end

      go_back

      with_accessibility_audits do
        assert_rule_violation "image-alt: Images must have alternative text" do
          click_on "Violate rule: image-alt"
        end
      end
    end

    it "flunks on calls to assert_no_accessibility_violations" do
      visit violations_path(rules: %w[label image-alt])

      assert_rule_violation(
        with: "label: Form elements must have labels",
        without: "image-alt: Images must have alternative text"
      ) do
        assert_no_accessibility_violations checking: "label", skipping: "image-alt"
      end
    end
  end

  describe "Skipping" do
    before do
      accessibility_audit_options.skipping = %w[label]
    end

    it "ignores violations" do
      visit violations_path
      click_on "Violate rule: label"
    end

    it "calls to with_accessibility_audit_options merge options" do
      with_accessibility_audit_options excluding: "img" do
        visit violations_path
        click_on "Violate rule: label"
        go_back
        click_on "Violate rule: image-alt"
      end
    end
  end

  describe "Skipping audit after method" do
    before do
      skip_accessibility_audit_after :visit, :click_on
    end

    it "does not audit after a skipped method" do
      visit violations_path
      click_on "Violate rule: label"
      go_back

      assert_rule_violation("label: Form elements must have labels") do
        click_link "Violate rule: label"
      end
    end
  end

  describe "Skipping rack_test drivers" do
    before do
      driven_by :rack_test
    end

    it "ignores violations" do
      visit violations_path
      click_on "Violate rule: label"
    end
  end

  def assert_rule_violation(rule = nil, with: rule, without: nil, &block)
    exception = assert_raises(Minitest::Assertion, &block)

    Array(with).flatten.each do |included|
      expect(exception.message).to include(included)
    end

    Array(without).flatten.each do |excluded|
      expect(exception.message).not_to include(excluded)
    end
  end
end
