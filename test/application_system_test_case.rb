require "test_helper"

Capybara.javascript_driver = ENV.fetch("DRIVER", "selenium_chrome_headless").to_sym

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by Capybara.javascript_driver, screen_size: [1400, 1400], options: {js_errors: true}

  def assert_rule_violation(rule = nil, with: rule, without: nil, &block)
    exception = assert_raises(Minitest::Assertion, &block)

    Array(with).flatten.each do |included|
      assert_includes exception.message, included
    end

    Array(without).flatten.each do |excluded|
      assert_not_includes exception.message, excluded
    end
  end
end

Capybara.server = :puma, {Silent: true}
