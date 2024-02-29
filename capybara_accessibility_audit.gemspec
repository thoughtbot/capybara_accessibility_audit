require_relative "lib/capybara_accessibility_audit/version"

Gem::Specification.new do |spec|
  spec.name = "capybara_accessibility_audit"
  spec.version = CapybaraAccessibilityAudit::VERSION
  spec.authors = ["Sean Doyle"]
  spec.email = ["sean.p.doyle24@gmail.com"]
  spec.homepage = "https://github.com/thoughtbot/capybara_accessibility_audit"
  spec.summary = "Accessibility tooling for Capybara"
  spec.description = "Accessibility tooling for Capybara"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/thoughtbot/capybara_accessibility_audit"
  spec.metadata["changelog_uri"] = "https://github.com/thoughtbot/capybara_accessibility_audit/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 6.1"
  spec.add_dependency "capybara"
  spec.add_dependency "axe-core-api"
  spec.add_dependency "zeitwerk"
end
