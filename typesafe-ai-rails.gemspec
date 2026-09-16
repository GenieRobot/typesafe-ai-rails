# frozen_string_literal: true

require_relative "lib/typesafe/rails/version"

Gem::Specification.new do |spec|
  spec.name        = "typesafe-ai-rails"
  spec.version     = Typesafe::Rails::VERSION
  spec.authors     = ["Genie Developments"]

  spec.summary     = "Community Rails integration for TypeSafe AI System One."
  spec.description = "Rails configuration, model-aware call/cost telemetry, and fail-closed " \
                     "confidence policies for TypeSafe Choice and Score judgments on top of " \
                     "the community typesafe-sdk Ruby gem. This is not an official TypeSafe package."
  spec.homepage    = "https://github.com/GenieRobot/typesafe-ai-rails"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"]          = spec.homepage
  spec.metadata["source_code_uri"]       = spec.homepage
  spec.metadata["changelog_uri"]         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"]       = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|\.github)/}) }
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "railties", ">= 7.0"
  spec.add_dependency "typesafe-sdk", "~> 0.3"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "sqlite3"
end
