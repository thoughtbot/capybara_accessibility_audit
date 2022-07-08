require "application_system_test_case"

class AuditAssertionsTest < ApplicationSystemTestCase
  test "flunks on violations detected after #visit" do
    assert_rule_violation "label: Form elements must have labels" do
      visit violations_path(rules: %w[label])
    end
  end

  test "flunks on violations detected after #click_on" do
    visit violations_path

    assert_rule_violation "label: Form elements must have labels" do
      click_on "Violate rule: label"
    end
  end

  test "flunks on violations detected after #click_link" do
    visit violations_path

    assert_rule_violation "label: Form elements must have labels" do
      click_link "Violate rule: label"
    end
  end

  test "flunks on violations detected after #click_button" do
    visit violations_path
    fill_in "Rules to violate", with: "label"

    assert_rule_violation "label: Form elements must have labels" do
      click_button "Submit"
    end
  end

  test "flunks on violations detected after #click_link_or_button" do
    visit violations_path

    assert_rule_violation "label: Form elements must have labels" do
      click_link_or_button "Violate rule: label"
    end
  end

  test "ignores violations within a matching skip_accessibility_violations block" do
    skip_accessibility_violations("label")    { visit violations_path(rules: %w[label]) }
    skip_accessibility_violations(%w[label])  { visit violations_path(rules: %w[label]) }
  end

  test "raises violations within a skip_accessibility_violation block that does not apply" do
    skip_accessibility_violations "label" do
      assert_rule_violation "image-alt: Images must have alternate text" do
        visit violations_path(rules: %w[image-alt])
      end
    end
  end
end

class DisablingAuditAssertionsTest < ApplicationSystemTestCase
  self.accessibility_audit_enabled = false

  test "ignores violations" do
    visit violations_path
    click_on "Violate rule: label"
    go_back
    click_on "Violate rule: image-alt"
  end

  test "flunks on calls within with_accessibility_audits" do
    with_accessibility_audits do
      assert_rule_violation "label: Form elements must have labels" do
        visit violations_path(rules: %w[label])
      end
    end
  end

  test "flunks on calls within with_accessibility_audits based on options" do
    visit violations_path

    with_accessibility_audits skipping: "label" do
      click_on "Violate rule: label"
    end

    go_back

    with_accessibility_audits do
      assert_rule_violation "image-alt: Images must have alternate text" do
        click_on "Violate rule: image-alt"
      end
    end
  end

  test "flunks on calls to assert_no_accessibility_violations" do
    visit violations_path(rules: %w[label image-alt])

    assert_rule_violation(
      with: "label: Form elements must have labels",
      without: "image-alt: Images must have alternate text"
    ) do
      assert_no_accessibility_violations checking: "label", skipping: "image-alt"
    end
  end
end

class SkippingAuditAssertionsTest < ApplicationSystemTestCase
  accessibility_audit_options.skipping = %w[label]

  test "ignores violations" do
    visit violations_path
    click_on "Violate rule: label"
  end

  test "calls to with_accessibility_audit_options merge options" do
    with_accessibility_audit_options excluding: "img" do
      visit violations_path
      click_on "Violate rule: label"
      go_back
      click_on "Violate rule: image-alt"
    end
  end
end
