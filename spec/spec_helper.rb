# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/application"
require "capybara_accessibility_audit"
require "rspec/rails"

Dummy::Application.initialize!

RSpec.configure do |config|
  config.use_active_record = false

  config.filter_rails_from_backtrace!
end

Capybara.javascript_driver = ENV.fetch("DRIVER", "selenium_chrome_headless").to_sym
Capybara.server = :puma, {Silent: true}
