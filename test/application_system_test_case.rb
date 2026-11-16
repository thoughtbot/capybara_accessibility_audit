require "test_helper"

Capybara.javascript_driver = ENV.fetch("DRIVER", "selenium_chrome_headless").to_sym

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by Capybara.javascript_driver, screen_size: [1400, 1400], options: {js_errors: true}

  def capture_report(&block)
    assert_raises(Minitest::Assertion, &block).message
  end

  def assert_rule_violation(rule = nil, with: rule, without: nil, &block)
    report = capture_report(&block)

    Array(with).flatten.each do |included|
      assert_includes report, included
    end

    Array(without).flatten.each do |excluded|
      assert_not_includes report, excluded
    end
  end
end

Capybara.server = :puma, {Silent: true}
