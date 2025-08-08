# frozen_string_literal: true

require "bundler/setup"

# Coverage
begin
  require "simplecov"
  SimpleCov.start do
    enable_coverage :branch
    add_filter "/test/"
  end
rescue LoadError
  warn "SimpleCov not available"
end

require "minitest/autorun"
require "minitest/reporters"
Minitest::Reporters.use!(Minitest::Reporters::SpecReporter.new)

require "active_support"
require "active_support/core_ext/numeric/time"
require "active_support/testing/time_helpers"
require "active_record"
require "logger"

# Minimal Rails logger for model callback rescues
require "rails"
Rails.logger = Logger.new($stdout)

# Establish in-memory database
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new($stdout)

# Define schema for tests
ActiveRecord::Schema.define do
  create_table :profiles, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :accounts, force: true do |t|
    t.string :email
    t.timestamps
  end

  create_table :trackable_activities, force: true do |t|
    t.string  :ip, null: false
    t.text    :country
    t.text    :city
    t.string  :trackable_type, null: false
    t.integer :trackable_id,   null: false
    t.string  :performer_type
    t.integer :performer_id
    t.text    :activity_type, null: false
    t.timestamps
  end

  add_index :trackable_activities, [:trackable_type, :trackable_id, :activity_type]
  add_index :trackable_activities, :activity_type
  add_index :trackable_activities, :country
end

require "footprinted"

# Test models
class Profile < ActiveRecord::Base
  include Footprinted::Model
end

class Account < ActiveRecord::Base
end

# Ensure clean state between tests
class Minitest::Test
  def after_teardown
    Footprinted::TrackableActivity.delete_all
    Profile.delete_all
    Account.delete_all
    super
  end
end

# Helper stubs for Trackdown
module TrackdownStub
  Location = Struct.new(:country_code, :city)

  def self.enable!(country: "US", city: "New York")
    Object.send(:remove_const, :Trackdown) if Object.const_defined?(:Trackdown)
    Object.const_set(:Trackdown, Module.new)
    Trackdown.define_singleton_method(:database_exists?) { true }
    Trackdown.define_singleton_method(:locate) { |_ip| Location.new(country, city) }
  end

  def self.disable!
    Object.send(:remove_const, :Trackdown) if Object.const_defined?(:Trackdown)
  end

  def self.set_database_exists!(value)
    Trackdown.define_singleton_method(:database_exists?) { value }
  end

  def self.set_locate_raising!(message = "boom")
    Trackdown.define_singleton_method(:locate) { |_ip| raise StandardError, message }
  end
end