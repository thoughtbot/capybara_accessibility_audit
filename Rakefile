require "bundler/setup"

load "rails/tasks/statistics.rake"

require "bundler/gem_tasks"
require "standard/rake"

namespace :test do
  task :prepare do
  end

  desc "Runs all tests, including system tests"
  task all: %w[test test:system]

  desc "Run system tests only"
  task system: %w[test:prepare] do
    $: << "test"

    Rails::TestUnit::Runner.rake_run(["test/system"])
  end
end
