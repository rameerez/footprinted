# frozen_string_literal: true

require "test_helper"

class Footprinted::UsagePatternsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    super
    @article = Article.create!(title: "Test Article")
    @user = User.create!(name: "Test User")
    stub_trackdown_locate(DEFAULT_LOCATION)
  end

  # -- LicenseSeat-like usage: rich metadata --

  def test_track_with_sdk_style_metadata
    metadata = {
      sdk_version: "0.4.0",
      os_name: "macOS",
      os_version: "15.2",
      platform: "macOS",
      device_model: "Mac15,3",
      app_version: "2.1.0",
      locale: "en_US",
      timezone: "America/Los_Angeles"
    }

    result = @article.track(:activation, ip: "203.0.113.50", metadata: metadata)

    assert result.persisted?
    parsed = parsed_metadata(result)
    assert_equal "0.4.0", parsed["sdk_version"]
    assert_equal "macOS", parsed["os_name"]
    assert_equal "15.2", parsed["os_version"]
    assert_equal "macOS", parsed["platform"]
    assert_equal "Mac15,3", parsed["device_model"]
    assert_equal "2.1.0", parsed["app_version"]
    assert_equal "en_US", parsed["locale"]
    assert_equal "America/Los_Angeles", parsed["timezone"]
  end

  # -- Multiple event types on same trackable --

  def test_multiple_event_types_on_same_trackable
    @article.track(:activation, ip: "1.1.1.1", metadata: { device_id: "abc" })
    @article.track(:validation, ip: "1.1.1.1", metadata: { device_id: "abc" })
    @article.track(:heartbeat, ip: "1.1.1.1", metadata: { device_id: "abc" })
    @article.track(:deactivation, ip: "1.1.1.1", metadata: { device_id: "abc" })

    assert_equal 4, @article.footprints.count
    types = @article.footprints.pluck(:event_type).sort
    assert_equal %w[activation deactivation heartbeat validation], types
  end

  # -- High-volume scenarios --

  def test_creating_many_footprints
    50.times do |i|
      @article.track(:heartbeat, ip: "1.1.1.#{i % 256}", metadata: { seq: i })
    end

    assert_equal 50, @article.footprints.count
  end

  def test_querying_many_footprints_by_event
    30.times { @article.track(:heartbeat, ip: "1.1.1.1") }
    20.times { @article.track(:activation, ip: "1.1.1.1") }

    assert_equal 30, @article.footprints.by_event("heartbeat").count
    assert_equal 20, @article.footprints.by_event("activation").count
  end

  # -- Stale device detection (no recent events) --

  def test_stale_device_detection_via_last_days
    # Old events
    5.times do
      Footprinted::Footprint.create!(
        ip: "1.1.1.1",
        event_type: "heartbeat",
        trackable: @article,
        occurred_at: 45.days.ago
      )
    end

    # Recent events
    3.times do
      Footprinted::Footprint.create!(
        ip: "2.2.2.2",
        event_type: "heartbeat",
        trackable: @article,
        occurred_at: 1.day.ago
      )
    end

    recent = @article.footprints.last_days(30)
    assert_equal 3, recent.count

    stale = @article.footprints.where("occurred_at < ?", 30.days.ago)
    assert_equal 5, stale.count
  end

  # -- Country distribution queries --

  def test_country_distribution
    us_location = MockLocationResult.new(
      country_code: "US", country_name: "United States", city: nil, region: nil,
      continent: nil, timezone: nil, latitude: nil, longitude: nil
    )
    de_location = MockLocationResult.new(
      country_code: "DE", country_name: "Germany", city: nil, region: nil,
      continent: nil, timezone: nil, latitude: nil, longitude: nil
    )

    # 3 US events
    stub_trackdown_locate(us_location)
    3.times { @article.track(:view, ip: "8.8.8.8") }

    # 2 DE events
    stub_trackdown_locate(de_location)
    2.times { @article.track(:view, ip: "1.1.1.1") }

    distribution = @article.footprints.group(:country_code).count
    assert_equal 3, distribution["US"]
    assert_equal 2, distribution["DE"]
  end

  def test_countries_class_method_returns_unique_codes
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: "US")
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: "US")
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: "DE")

    countries = Footprinted::Footprint.countries
    assert_equal 2, countries.size
    assert_includes countries, "US"
    assert_includes countries, "DE"
  end

  # -- Time-series queries using scopes --

  def test_time_series_last_days_combined_with_by_event
    # Create events spread across days
    [1, 2, 3, 10, 15].each do |days_ago|
      @article.track(:view, ip: "1.1.1.1", occurred_at: days_ago.days.ago)
    end
    [1, 5, 20].each do |days_ago|
      @article.track(:download, ip: "1.1.1.1", occurred_at: days_ago.days.ago)
    end

    # Views in last 7 days
    recent_views = @article.footprints.by_event("view").last_days(7)
    assert_equal 3, recent_views.count

    # Downloads in last 7 days
    recent_downloads = @article.footprints.by_event("download").last_days(7)
    assert_equal 2, recent_downloads.count
  end

  def test_between_scope_with_specific_range
    t1 = Time.new(2025, 6, 1, 0, 0, 0, "+00:00")
    t2 = Time.new(2025, 6, 15, 0, 0, 0, "+00:00")
    t3 = Time.new(2025, 6, 30, 0, 0, 0, "+00:00")
    t4 = Time.new(2025, 7, 15, 0, 0, 0, "+00:00")

    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: t1)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: t2)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: t3)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: t4)

    results = Footprinted::Footprint.between(t2, t3)
    assert_equal 2, results.count
  end

  # -- Event types class method --

  def test_event_types_returns_all_distinct_types
    @article.track(:activation, ip: "1.1.1.1")
    @article.track(:validation, ip: "1.1.1.1")
    @article.track(:heartbeat, ip: "1.1.1.1")
    @article.track(:activation, ip: "1.1.1.1") # duplicate

    types = Footprinted::Footprint.event_types
    assert_equal 3, types.size
    assert_includes types, "activation"
    assert_includes types, "validation"
    assert_includes types, "heartbeat"
  end

  # -- Scoped association queries --

  def test_scoped_views_scope_chaining
    @article.track_view(ip: "1.1.1.1")
    @article.track_view(ip: "2.2.2.2")
    @article.track_download(ip: "3.3.3.3")

    recent_views = @article.views.recent
    assert_equal 2, recent_views.count
    recent_views.each { |v| assert_equal "view", v.event_type }
  end

  def test_scoped_downloads_with_last_days
    @article.track_download(ip: "1.1.1.1", occurred_at: 2.days.ago)
    @article.track_download(ip: "2.2.2.2", occurred_at: 20.days.ago)

    recent = @article.downloads.last_days(7)
    assert_equal 1, recent.count
  end

  # -- Async round-trip for generic track --

  def test_async_generic_track_round_trip
    Footprinted.configuration.async = true

    perform_enqueued_jobs do
      @article.track(:validation, ip: "8.8.4.4", metadata: { key: "abc123" })
    end

    assert_equal 1, Footprinted::Footprint.count
    fp = Footprinted::Footprint.last
    assert_equal "validation", fp.event_type
    assert_equal "8.8.4.4", fp.ip

    metadata = parsed_metadata(fp)
    assert_equal "abc123", metadata["key"]
  end

  # -- Performer-based querying --

  def test_performer_scoped_queries
    user2 = User.create!(name: "User 2")

    @article.track(:view, ip: "1.1.1.1", performer: @user)
    @article.track(:view, ip: "2.2.2.2", performer: user2)
    @article.track(:view, ip: "3.3.3.3") # no performer

    assert_equal 1, @article.footprints.performed_by(@user).count
    assert_equal 1, @article.footprints.performed_by(user2).count
  end

  private

  def parsed_metadata(footprint)
    metadata = footprint.metadata
    metadata.is_a?(String) ? JSON.parse(metadata) : metadata
  end

  def stub_trackdown_locate(location)
    verbose_was, $VERBOSE = $VERBOSE, nil
    Trackdown.define_singleton_method(:locate) do |ip, request: nil|
      location
    end
  ensure
    $VERBOSE = verbose_was
  end
end
