# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/application"
require "capybara_accessibility_audit"
require "rspec/rails"

Dummy::Application.initialize!

module ReporterSpecHelpers
  def capture_report(&block)
    assert_raises(Minitest::Assertion, &block).message
  end

  def assert_rule_violation(rule = nil, with: rule, without: nil, &block)
    report = capture_report(&block)

    Array(with).flatten.each do |included|
      expect(report).to include(included)
    end

    Array(without).flatten.each do |excluded|
      expect(report).not_to include(excluded)
    end
  end
end

RSpec.configure do |config|
  config.use_active_record = false

  config.filter_rails_from_backtrace!

  config.include Rspec::Matchers::ActiveSupport::Notifications
  config.include ReporterSpecHelpers, type: :system
end

Capybara.javascript_driver = ENV.fetch("DRIVER", "selenium_chrome_headless").to_sym
Capybara.server = :puma, {Silent: true}
