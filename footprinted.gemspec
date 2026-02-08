# frozen_string_literal: true

require_relative "lib/footprinted/version"

Gem::Specification.new do |spec|
  spec.name = "footprinted"
  spec.version = Footprinted::VERSION
  spec.authors = ["rameerez"]
  spec.email = ["rubygems@rameerez.com"]

  spec.summary = "Track IP-geolocated user activity in your Rails app"
  spec.description = "Track user activity with associated IP addresses, geolocation info, and metadata, easily and with minimal setup. Supports async tracking via ActiveJob. It's good for tracking profile views, downloads, login attempts, or any user interaction where location matters."
  spec.homepage = "https://github.com/rameerez/footprinted"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/rameerez/footprinted"
  spec.metadata["changelog_uri"] = "https://github.com/rameerez/footprinted/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "trackdown", "~> 0.2"
end
