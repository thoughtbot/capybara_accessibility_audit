# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
require "rails/test_help"

Rails.root.glob("../../test/support/**/*.rb").each { |file| require file }
