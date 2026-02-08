# frozen_string_literal: true

require_relative "lib/footprinted/version"

Gem::Specification.new do |spec|
  spec.name = "footprinted"
  spec.version = Footprinted::VERSION
  spec.authors = ["rameerez"]
  spec.email = ["rubygems@rameerez.com"]

  spec.summary = "Simple event tracking for Rails apps"
  spec.description = "Add event tracking to any Rails model easily. Every event adds automatic IP geolocation, and any arbitrary metadata you may want to add. The gem comes with polymorphic associations, and async support via ActiveJob, so you can track events in the background without any overhead. Great for tracking login attempts, file downloads, profile visits, or any interaction where knowing the where matters. It also allows you to trivially build analytics dashboards and audit logs for all your app events."
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
  spec.add_dependency "trackdown", "~> 0.3"
end
