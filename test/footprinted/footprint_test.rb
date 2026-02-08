# frozen_string_literal: true

require "test_helper"

class Footprinted::FootprintTest < ActiveSupport::TestCase
  def setup
    super
    @article = Article.create!(title: "Test Article")
    @user = User.create!(name: "Test User")
    stub_trackdown_locate(DEFAULT_LOCATION)
  end

  # -- Table name --

  def test_table_name
    assert_equal "footprints", Footprinted::Footprint.table_name
  end

  # -- Validations --

  def test_validates_ip_presence
    footprint = Footprinted::Footprint.new(
      ip: nil,
      event_type: "view",
      trackable: @article
    )
    refute footprint.valid?
    assert_includes footprint.errors[:ip], "can't be blank"
  end

  def test_validates_event_type_presence
    footprint = Footprinted::Footprint.new(
      ip: "1.2.3.4",
      event_type: nil,
      trackable: @article
    )
    refute footprint.valid?
    assert_includes footprint.errors[:event_type], "can't be blank"
  end

  def test_validates_occurred_at_presence_auto_set
    footprint = Footprinted::Footprint.new(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      occurred_at: nil
    )
    # Before validation, occurred_at is nil. Validation callback sets it.
    assert footprint.valid?
    assert_not_nil footprint.occurred_at
  end

  def test_valid_with_all_required_fields
    footprint = Footprinted::Footprint.new(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article
    )
    assert footprint.valid?
  end

  # -- Associations --

  def test_belongs_to_trackable_polymorphic
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article
    )
    assert_equal @article, footprint.trackable
    assert_equal "Article", footprint.trackable_type
    assert_equal @article.id, footprint.trackable_id
  end

  def test_belongs_to_performer_polymorphic_optional
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      performer: @user
    )
    assert_equal @user, footprint.performer
    assert_equal "User", footprint.performer_type
  end

  def test_performer_is_optional
    footprint = Footprinted::Footprint.new(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      performer: nil
    )
    assert footprint.valid?
  end

  # -- Callbacks: set_occurred_at --

  def test_set_occurred_at_defaults_to_current_time
    freeze_time = Time.new(2025, 6, 15, 12, 0, 0, "+00:00")
    travel_to freeze_time do
      footprint = Footprinted::Footprint.new(
        ip: "1.2.3.4",
        event_type: "view",
        trackable: @article
      )
      footprint.valid?
      assert_equal freeze_time.to_i, footprint.occurred_at.to_i
    end
  end

  def test_set_occurred_at_does_not_override_existing_value
    custom_time = Time.new(2024, 1, 1, 0, 0, 0, "+00:00")
    footprint = Footprinted::Footprint.new(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      occurred_at: custom_time
    )
    footprint.valid?
    assert_equal custom_time, footprint.occurred_at
  end

  # -- Callbacks: set_geolocation_data --

  def test_set_geolocation_data_populates_geo_fields
    footprint = Footprinted::Footprint.create!(
      ip: "8.8.8.8",
      event_type: "view",
      trackable: @article
    )
    assert_equal "US", footprint.country_code
    assert_equal "United States", footprint.country_name
    assert_equal "San Francisco", footprint.city
    assert_equal "California", footprint.region
    assert_equal "NA", footprint.continent
    assert_equal "America/Los_Angeles", footprint.timezone
    assert_in_delta 37.7749, footprint.latitude.to_f, 0.001
    assert_in_delta(-122.4194, footprint.longitude.to_f, 0.001)
  end

  def test_set_geolocation_data_skips_if_country_code_already_present
    called = false
    stub_trackdown_locate(DEFAULT_LOCATION) { called = true }

    footprint = Footprinted::Footprint.create!(
      ip: "8.8.8.8",
      event_type: "view",
      trackable: @article,
      country_code: "DE"
    )
    refute called, "Trackdown.locate should not be called when country_code is present"
    assert_equal "DE", footprint.country_code
  end

  def test_set_geolocation_data_rescues_errors_gracefully
    stub_trackdown_locate_error("API failure")

    # Should not raise, should save successfully without geo data
    footprint = Footprinted::Footprint.create!(
      ip: "8.8.8.8",
      event_type: "view",
      trackable: @article
    )
    assert_nil footprint.country_code
  end

  def test_set_geolocation_data_passes_request_instance_variable
    captured_request = nil
    stub_trackdown_locate(DEFAULT_LOCATION) { |ip, req| captured_request = req }

    mock_request = Object.new
    footprint = Footprinted::Footprint.new(
      ip: "8.8.8.8",
      event_type: "view",
      trackable: @article
    )
    footprint.instance_variable_set(:@_request, mock_request)
    footprint.save!

    assert_equal mock_request, captured_request
  end

  # -- Scopes --

  def test_scope_by_event
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "download", trackable: @article)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article)

    assert_equal 2, Footprinted::Footprint.by_event("view").count
    assert_equal 1, Footprinted::Footprint.by_event("download").count
    assert_equal 0, Footprinted::Footprint.by_event("nonexistent").count
  end

  def test_scope_by_country
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: "US")
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: "DE")
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: "US")

    assert_equal 2, Footprinted::Footprint.by_country("US").count
    assert_equal 1, Footprinted::Footprint.by_country("DE").count
  end

  def test_scope_recent
    old = Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: 3.days.ago)
    new_fp = Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: 1.day.ago)

    results = Footprinted::Footprint.recent
    assert_equal new_fp.id, results.first.id
    assert_equal old.id, results.last.id
  end

  def test_scope_between
    old = Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: 10.days.ago)
    mid = Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: 5.days.ago)
    recent = Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: 1.day.ago)

    results = Footprinted::Footprint.between(6.days.ago, Time.current)
    assert_includes results, mid
    assert_includes results, recent
    refute_includes results, old
  end

  def test_scope_last_days
    old = Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: 10.days.ago)
    recent = Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: 1.day.ago)

    results = Footprinted::Footprint.last_days(5)
    assert_includes results, recent
    refute_includes results, old
  end

  def test_scope_performed_by
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, performer: @user)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article)

    results = Footprinted::Footprint.performed_by(@user)
    assert_equal 1, results.count
    assert_equal @user, results.first.performer
  end

  # -- Class methods --

  def test_event_types
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "download", trackable: @article)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article)

    types = Footprinted::Footprint.event_types
    assert_includes types, "view"
    assert_includes types, "download"
    assert_equal 2, types.size
  end

  def test_countries
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: "US")
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: "DE")
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: nil)

    countries = Footprinted::Footprint.countries
    assert_includes countries, "US"
    assert_includes countries, "DE"
    assert_equal 2, countries.size
  end

  def test_countries_excludes_nil
    nil_location = MockLocationResult.new(
      country_code: nil, country_name: nil, city: nil, region: nil,
      continent: nil, timezone: nil, latitude: nil, longitude: nil
    )
    stub_trackdown_locate(nil_location)

    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: nil)

    assert_empty Footprinted::Footprint.countries
  end

  # -- Edge cases --

  def test_blank_event_type_is_invalid
    footprint = Footprinted::Footprint.new(
      ip: "1.2.3.4",
      event_type: "",
      trackable: @article
    )
    refute footprint.valid?
  end

  def test_scope_chaining
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: "US", occurred_at: 1.day.ago)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: "DE", occurred_at: 1.day.ago)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "download", trackable: @article, country_code: "US", occurred_at: 1.day.ago)

    results = Footprinted::Footprint.by_event("view").by_country("US")
    assert_equal 1, results.count
  end

  private

  def stub_trackdown_locate(location, &block)
    verbose_was, $VERBOSE = $VERBOSE, nil
    Trackdown.define_singleton_method(:locate) do |ip, request: nil|
      block&.call(ip, request)
      location
    end
  ensure
    $VERBOSE = verbose_was
  end

  def stub_trackdown_locate_error(message)
    verbose_was, $VERBOSE = $VERBOSE, nil
    Trackdown.define_singleton_method(:locate) do |ip, request: nil|
      raise StandardError, message
    end
  ensure
    $VERBOSE = verbose_was
  end
end
