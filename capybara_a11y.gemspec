require_relative "lib/capybara_a11y/version"

Gem::Specification.new do |spec|
  spec.name = "capybara_a11y"
  spec.version = CapybaraA11y::VERSION
  spec.authors = ["Sean Doyle"]
  spec.email = ["sean.p.doyle24@gmail.com"]
  spec.homepage = "https://github.com/thoughtbot/capybara_a11y"
  spec.summary = "Accessibility tooling for Capybara"
  spec.description = "Accessibility tooling for Capybara"
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/thoughtbot/capybara_a11y"
  spec.metadata["changelog_uri"] = "https://github.com/thoughtbot/capybara_a11y/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails"
end
