# frozen_string_literal: true

require "test_helper"

class Footprinted::ModelTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    super
    @article = Article.create!(title: "Test Article")
    @user = User.create!(name: "Test User")
    stub_trackdown_locate(DEFAULT_LOCATION)
  end

  # -- included block --

  def test_included_creates_footprints_association
    assert_respond_to @article, :footprints
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @article.footprints
  end

  def test_footprints_association_is_polymorphic
    footprint = Footprinted::Footprint.create!(
      ip: "1.1.1.1",
      event_type: "view",
      trackable: @article
    )
    assert_includes @article.footprints, footprint
  end

  def test_footprints_dependent_destroy
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article)
    assert_equal 1, Footprinted::Footprint.count

    @article.destroy
    assert_equal 0, Footprinted::Footprint.count
  end

  # -- has_trackable DSL --

  def test_has_trackable_creates_scoped_association
    assert_respond_to @article, :views
    assert_respond_to @article, :downloads
  end

  def test_has_trackable_association_filters_by_event_type
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "download", trackable: @article)

    assert_equal 1, @article.views.count
    assert_equal 1, @article.downloads.count
  end

  def test_has_trackable_creates_track_method
    assert_respond_to @article, :track_view
    assert_respond_to @article, :track_download
  end

  # -- track_<event_type> method (sync) --

  def test_track_method_creates_footprint_sync
    result = @article.track_view(ip: "8.8.8.8")

    assert_instance_of Footprinted::Footprint, result
    assert result.persisted?
    assert_equal "8.8.8.8", result.ip
    assert_equal "view", result.event_type
    assert_equal @article, result.trackable
  end

  def test_track_method_with_performer
    result = @article.track_view(ip: "8.8.8.8", performer: @user)

    assert_equal @user, result.performer
  end

  def test_track_method_with_metadata
    result = @article.track_view(ip: "8.8.8.8", metadata: { browser: "Chrome" })

    metadata = result.metadata
    metadata = JSON.parse(metadata) if metadata.is_a?(String)
    assert_equal "Chrome", metadata["browser"]
  end

  def test_track_method_with_occurred_at
    custom_time = Time.new(2024, 6, 15, 12, 0, 0, "+00:00")
    result = @article.track_view(ip: "8.8.8.8", occurred_at: custom_time)

    assert_equal custom_time.to_i, result.occurred_at.to_i
  end

  def test_track_method_with_request
    mock_request = Object.new
    result = @article.track_view(ip: "8.8.8.8", request: mock_request)

    assert result.persisted?
  end

  def test_track_method_defaults_occurred_at_to_current
    freeze_time = Time.new(2025, 6, 15, 12, 0, 0, "+00:00")
    travel_to freeze_time do
      result = @article.track_view(ip: "8.8.8.8")
      assert_equal freeze_time.to_i, result.occurred_at.to_i
    end
  end

  # -- track_<event_type> method (async) --

  def test_track_method_enqueues_job_when_async
    Footprinted.configuration.async = true

    assert_enqueued_with(job: Footprinted::TrackJob) do
      @article.track_view(ip: "8.8.8.8")
    end
  end

  def test_track_method_async_does_not_create_footprint_immediately
    Footprinted.configuration.async = true

    @article.track_view(ip: "8.8.8.8")
    assert_equal 0, Footprinted::Footprint.count
  end

  def test_track_method_async_passes_correct_arguments
    Footprinted.configuration.async = true

    assert_enqueued_with(
      job: Footprinted::TrackJob,
      args: ->(args) {
        args[0] == "Article" &&
          args[1] == @article.id &&
          args[2][:ip] == "8.8.8.8" &&
          args[2][:event_type] == "view"
      }
    ) do
      @article.track_view(ip: "8.8.8.8")
    end
  end

  # -- Generic track() method (sync) --

  def test_track_creates_footprint_with_arbitrary_event_type
    result = @article.track("signup", ip: "8.8.8.8")

    assert_instance_of Footprinted::Footprint, result
    assert result.persisted?
    assert_equal "signup", result.event_type
    assert_equal "8.8.8.8", result.ip
    assert_equal @article, result.trackable
  end

  def test_track_with_symbol_event_type_converts_to_string
    result = @article.track(:login, ip: "8.8.8.8")

    assert_equal "login", result.event_type
  end

  def test_track_with_performer
    result = @article.track("view", ip: "8.8.8.8", performer: @user)

    assert_equal @user, result.performer
  end

  def test_track_with_metadata
    result = @article.track("view", ip: "8.8.8.8", metadata: { source: "api" })

    metadata = result.metadata
    metadata = JSON.parse(metadata) if metadata.is_a?(String)
    assert_equal "api", metadata["source"]
  end

  def test_track_with_request
    mock_request = Object.new
    result = @article.track("view", ip: "8.8.8.8", request: mock_request)

    assert result.persisted?
  end

  def test_track_with_occurred_at
    custom_time = Time.new(2024, 1, 1, 0, 0, 0, "+00:00")
    result = @article.track("view", ip: "8.8.8.8", occurred_at: custom_time)

    assert_equal custom_time.to_i, result.occurred_at.to_i
  end

  # -- Generic track() method (async) --

  def test_track_enqueues_job_when_async
    Footprinted.configuration.async = true

    assert_enqueued_with(job: Footprinted::TrackJob) do
      @article.track("view", ip: "8.8.8.8")
    end
  end

  def test_track_async_does_not_create_footprint_immediately
    Footprinted.configuration.async = true

    @article.track("view", ip: "8.8.8.8")
    assert_equal 0, Footprinted::Footprint.count
  end

  def test_track_async_serializes_occurred_at_as_iso8601
    Footprinted.configuration.async = true

    assert_enqueued_with(
      job: Footprinted::TrackJob,
      args: ->(args) {
        attrs = args[2]
        attrs[:occurred_at].is_a?(String) && Time.parse(attrs[:occurred_at])
      }
    ) do
      @article.track("view", ip: "8.8.8.8")
    end
  end

  def test_track_async_extracts_geo_data_when_request_passed
    Footprinted.configuration.async = true

    # Stub Trackdown to return geo data when request is passed
    mock_location = Struct.new(:country_code, :country_name, :city, :region, :continent, :timezone, :latitude, :longitude).new(
      "US", "United States", "San Francisco", "California", "NA", "America/Los_Angeles", 37.7749, -122.4194
    )
    stub_trackdown_locate_with_request(mock_location)

    mock_request = Object.new

    assert_enqueued_with(
      job: Footprinted::TrackJob,
      args: ->(args) {
        attrs = args[2]
        attrs[:country_code] == "US" &&
        attrs[:city] == "San Francisco" &&
        attrs[:latitude] == 37.7749
      }
    ) do
      @article.track("view", ip: "8.8.8.8", request: mock_request)
    end
  end

  def test_track_async_without_request_does_not_extract_geo_data
    Footprinted.configuration.async = true

    assert_enqueued_with(
      job: Footprinted::TrackJob,
      args: ->(args) {
        attrs = args[2]
        !attrs.key?(:country_code)
      }
    ) do
      @article.track("view", ip: "8.8.8.8")
    end
  end

  # -- footprints association via track --

  def test_track_adds_to_footprints_association
    @article.track("view", ip: "8.8.8.8")
    @article.track("download", ip: "8.8.8.8")

    assert_equal 2, @article.footprints.count
  end

  private

  def stub_trackdown_locate(location)
    verbose_was, $VERBOSE = $VERBOSE, nil
    Trackdown.define_singleton_method(:locate) do |ip, request: nil|
      location
    end
  ensure
    $VERBOSE = verbose_was
  end

  def stub_trackdown_locate_with_request(location)
    verbose_was, $VERBOSE = $VERBOSE, nil
    empty_location = Struct.new(:country_code, :country_name, :city, :region, :continent, :timezone, :latitude, :longitude).new(nil, nil, nil, nil, nil, nil, nil, nil)
    Trackdown.define_singleton_method(:locate) do |ip, request: nil|
      # Only return geo data when request is passed
      request ? location : empty_location
    end
  ensure
    $VERBOSE = verbose_was
  end
end
