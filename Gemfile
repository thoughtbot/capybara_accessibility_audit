source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in capybara_accessibility_audit.gemspec.
gemspec

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"

rails_version = ENV.fetch("RAILS_VERSION", "7.0")

rails_constraint = if rails_version == "main"
  {github: "rails/rails"}
else
  "~> #{rails_version}.0"
end

gem "rails", rails_constraint
gem "rspec-rails"

gem "puma"
gem "standard", "~> 1.12"
gem "selenium-webdriver"
