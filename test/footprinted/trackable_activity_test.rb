# frozen_string_literal: true

require "test_helper"

class FootprintedTrackableActivityTest < Minitest::Test
  include ActiveSupport::Testing::TimeHelpers

  def setup
    TrackdownStub.enable!
  end

  def teardown
    TrackdownStub.disable!
  end

  def build_profile(name: "X")
    Profile.create!(name: name)
  end

  def test_validations
    activity = Footprinted::TrackableActivity.new
    refute activity.valid?
    assert_includes activity.errors.attribute_names, :ip
    assert_includes activity.errors.attribute_names, :activity_type
    assert_includes activity.errors.attribute_names, :trackable
  end

  def test_associations
    profile = build_profile
    activity = Footprinted::TrackableActivity.create!(ip: "1.1.1.1", activity_type: "x", trackable: profile)
    assert_equal profile, activity.trackable
    assert_nil activity.performer

    performer = Account.create!(email: "p@example.com")
    activity.update!(performer: performer)
    assert_equal performer, activity.performer
  end

  def test_geolocation_success_sets_country_and_city
    profile = build_profile
    activity = Footprinted::TrackableActivity.create!(ip: "1.1.1.1", activity_type: "x", trackable: profile)
    assert_equal "US", activity.country
    assert_equal "New York", activity.city
  end

  def test_no_raise_when_trackdown_missing
    profile = build_profile
    TrackdownStub.disable!
    activity = Footprinted::TrackableActivity.create!(ip: "1.1.1.1", activity_type: "x", trackable: profile)
    assert activity.persisted?
    assert_nil activity.country
    assert_nil activity.city
  ensure
    TrackdownStub.enable!
  end

  def test_no_raise_when_database_missing
    profile = build_profile
    TrackdownStub.set_database_exists!(false)
    activity = Footprinted::TrackableActivity.create!(ip: "1.1.1.1", activity_type: "x", trackable: profile)
    assert activity.persisted?
    assert_nil activity.country
    assert_nil activity.city
  ensure
    TrackdownStub.set_database_exists!(true)
  end

  def test_logs_and_continues_when_locate_raises
    TrackdownStub.set_locate_raising!("test error")
    profile = build_profile
    activity = Footprinted::TrackableActivity.create!(ip: "1.1.1.1", activity_type: "x", trackable: profile)
    assert_nil activity.country
    assert_nil activity.city
    assert activity.persisted?
  end

  def test_scopes_and_class_methods
    Footprinted::TrackableActivity.delete_all
    profile = build_profile
    performer = Account.create!(email: "p@example.com")

    travel_to Time.utc(2024, 1, 1, 12) do
      TrackdownStub.enable!(country: "US", city: "NY")
      Footprinted::TrackableActivity.create!(ip: "1.1.1.1", activity_type: "view", trackable: profile, performer: performer)
    end
    travel_to Time.utc(2024, 1, 2, 12) do
      TrackdownStub.enable!(country: "UK", city: "London")
      Footprinted::TrackableActivity.create!(ip: "2.2.2.2", activity_type: "view", trackable: profile)
    end
    travel_to Time.utc(2024, 1, 3, 12) do
      TrackdownStub.enable!(country: "US", city: "Boston")
      Footprinted::TrackableActivity.create!(ip: "3.3.3.3", activity_type: "download", trackable: profile)
    end

    assert_equal 2, Footprinted::TrackableActivity.by_activity("view").count
    assert_equal 2, Footprinted::TrackableActivity.by_country("US").count
    assert_equal ["download", "view"].sort, Footprinted::TrackableActivity.activity_types.sort
    assert_equal ["UK", "US"].sort, Footprinted::TrackableActivity.countries.sort

    # performed_by
    assert_equal 1, Footprinted::TrackableActivity.performed_by(performer).count

    # recent ordering
    recent = Footprinted::TrackableActivity.recent.to_a
    assert_operator recent.first.created_at, :>=, recent.last.created_at

    # between and last_days
    range = Footprinted::TrackableActivity.between(Time.utc(2024, 1, 2), Time.utc(2024, 1, 3, 23, 59, 59))
    assert_equal 2, range.count

    # last_days depends on current time; ensure the 3 records we created are included with a sufficiently large window
    assert Footprinted::TrackableActivity.last_days(1000).count >= 3
  end
end