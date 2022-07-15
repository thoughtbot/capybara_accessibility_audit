require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium_headless, using: :headless_chrome, screen_size: [1400, 1400]

  def self.debug!
    driven_by :selenium, using: :chrome, screen_size: [1400, 1400]
  end

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
