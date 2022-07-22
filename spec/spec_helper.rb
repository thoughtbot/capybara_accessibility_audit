# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/application"
require "capybara_accessibility_audit"
require "rspec/rails"

Dummy::Application.initialize!

module FeatureSpecBackports
  def driven_by(name, **)
    Capybara.current_driver = Capybara.javascript_driver = name
  end
end

RSpec.configure do |config|
  config.use_active_record = false

  config.filter_rails_from_backtrace!

  config.include FeatureSpecBackports, type: :feature
end

Capybara.server = :puma, {Silent: true}
