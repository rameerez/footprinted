# frozen_string_literal: true

require "simplecov"

require "minitest/autorun"
require "minitest/reporters"
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

require "mocha/minitest"

# Load Rails frameworks individually (no full Rails boot)
require "active_record"
require "active_job"
require "active_support"
require "active_support/testing/time_helpers"

# Minimal Rails module stubs for Rails.logger used in Footprint#set_geolocation_data
require "rails"

verbose_was, $VERBOSE = $VERBOSE, nil
module Rails
  def self.logger
    @logger ||= Logger.new(IO::NULL)
  end

  def self.logger=(val)
    @logger = val
  end
end
$VERBOSE = verbose_was

# Set up in-memory SQLite database
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil

ActiveRecord::Schema.define do
  create_table :footprints, force: true do |t|
    t.string  :ip
    t.string  :country_code,  limit: 2
    t.string  :country_name
    t.string  :city
    t.string  :region
    t.string  :continent,     limit: 2
    t.string  :timezone
    t.decimal :latitude,  precision: 10, scale: 7
    t.decimal :longitude, precision: 10, scale: 7

    t.references :trackable, polymorphic: true, null: false
    t.references :performer, polymorphic: true

    t.string  :event_type, null: false
    t.text    :metadata,   null: false, default: "{}"
    t.datetime :occurred_at, null: false

    t.timestamps
  end

  create_table :articles, force: true do |t|
    t.string :title
    t.timestamps
  end

  create_table :users, force: true do |t|
    t.string :name
    t.timestamps
  end
end

# Require the gem (skips railtie since Rails::Railtie won't be fully loaded)
require "footprinted"

# Explicitly require the TrackJob since it lives in app/jobs/ and isn't auto-loaded
require_relative "../app/jobs/footprinted/track_job"

# Define a mock LocationResult for Trackdown stubs
MockLocationResult = Struct.new(
  :country_code, :country_name, :city, :region, :continent, :timezone, :latitude, :longitude,
  keyword_init: true
)

DEFAULT_LOCATION = MockLocationResult.new(
  country_code: "US",
  country_name: "United States",
  city: "San Francisco",
  region: "California",
  continent: "NA",
  timezone: "America/Los_Angeles",
  latitude: 37.7749,
  longitude: -122.4194
)

# Stub Trackdown module if not already defined by the gem
module Trackdown
  class Error < StandardError; end

  def self.locate(ip, request: nil)
    DEFAULT_LOCATION
  end
end

# Test model classes
class Article < ActiveRecord::Base
  include Footprinted::Model
  has_trackable :views
  has_trackable :downloads
end

class User < ActiveRecord::Base
end

# Override metadata serialization for SQLite (text column instead of jsonb)
Footprinted::Footprint.serialize :metadata, coder: JSON

# Configure ActiveJob for testing
ActiveJob::Base.queue_adapter = :test

# Base test class with common helpers
class ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  # Clean footprints between tests
  def setup
    Footprinted::Footprint.delete_all
    Footprinted.reset
    ActiveJob::Base.queue_adapter = :test
  end
end
