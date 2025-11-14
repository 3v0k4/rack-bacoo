# frozen_string_literal: true

require_relative "lib/rack/bacoo/version"

Gem::Specification.new do |spec|
  spec.name = "rack-bacoo"
  spec.version = Rack::Bacoo::VERSION
  spec.authors = ["3v0k4"]
  spec.email = ["riccardo.odone@gmail.com"]

  spec.summary = "Combine HTTP Basic Authentication with a session cookie"
  spec.description = "Rack::Bacoo combines HTTP Basic Authentication with a session cookie so that you don't have to input username and password on each visit. The session cookie is encrypted (aes-256-gcm), and the password inside is hashed (bcrypt)."
  spec.homepage = "https://github.com/3v0k4/rack-bacoo"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/3v0k4/rack-bacoo/blob/main/CHANGELOG.md"

  spec.files = Dir.glob("lib/**/*") + Dir.glob("exe/*")
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "base64"
  spec.add_dependency "bcrypt", "~> 3.1"
  spec.add_dependency "rack", "~> 3.2"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata["rubygems_mfa_required"] = "true"
end
