# frozen_string_literal: true

require "test_helper"

class Footprinted::ModelEdgeCasesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    super
    @article = Article.create!(title: "Test Article")
    @user = User.create!(name: "Test User")
    stub_trackdown_locate(DEFAULT_LOCATION)
  end

  # -- Multiple has_trackable declarations --

  def test_multiple_has_trackable_creates_independent_associations
    assert_respond_to @article, :views
    assert_respond_to @article, :downloads
    assert_respond_to @article, :track_view
    assert_respond_to @article, :track_download
  end

  def test_scoped_association_independence
    @article.track_view(ip: "1.1.1.1")
    @article.track_view(ip: "2.2.2.2")
    @article.track_download(ip: "3.3.3.3")

    assert_equal 2, @article.views.count
    assert_equal 1, @article.downloads.count

    # Views should not contain downloads
    @article.views.each do |v|
      assert_equal "view", v.event_type
    end

    # Downloads should not contain views
    @article.downloads.each do |d|
      assert_equal "download", d.event_type
    end
  end

  def test_footprints_returns_all_event_types
    @article.track_view(ip: "1.1.1.1")
    @article.track_download(ip: "2.2.2.2")

    assert_equal 2, @article.footprints.count
  end

  # -- Track with all parameters vs minimal --

  def test_track_with_all_parameters
    custom_time = Time.new(2025, 3, 15, 10, 0, 0, "+00:00")
    mock_request = Object.new

    result = @article.track_view(
      ip: "8.8.8.8",
      request: mock_request,
      performer: @user,
      metadata: { browser: "Chrome", version: "120" },
      occurred_at: custom_time
    )

    assert result.persisted?
    assert_equal "8.8.8.8", result.ip
    assert_equal "view", result.event_type
    assert_equal @user, result.performer
    assert_equal custom_time.to_i, result.occurred_at.to_i

    metadata = parsed_metadata(result)
    assert_equal "Chrome", metadata["browser"]
    assert_equal "120", metadata["version"]
  end

  def test_track_with_minimal_parameters
    result = @article.track_view(ip: "1.2.3.4")

    assert result.persisted?
    assert_equal "1.2.3.4", result.ip
    assert_equal "view", result.event_type
    assert_nil result.performer
    assert_not_nil result.occurred_at
  end

  # -- Track with request object vs nil --

  def test_track_with_nil_request
    result = @article.track_view(ip: "8.8.8.8", request: nil)
    assert result.persisted?
  end

  def test_track_with_request_object_passes_to_footprint
    mock_request = Object.new
    result = @article.track_view(ip: "8.8.8.8", request: mock_request)
    assert result.persisted?
  end

  # -- Async mode edge cases --

  def test_async_mode_serializes_metadata_as_hash
    Footprinted.configuration.async = true

    assert_enqueued_with(
      job: Footprinted::TrackJob,
      args: ->(args) {
        attrs = args[2]
        attrs[:metadata].is_a?(Hash) && attrs[:metadata][:browser] == "Chrome"
      }
    ) do
      @article.track_view(ip: "8.8.8.8", metadata: { browser: "Chrome" })
    end
  end

  def test_async_mode_serializes_occurred_at_as_iso8601
    Footprinted.configuration.async = true

    assert_enqueued_with(
      job: Footprinted::TrackJob,
      args: ->(args) {
        attrs = args[2]
        occurred_at = attrs[:occurred_at]
        occurred_at.is_a?(String) && Time.parse(occurred_at).is_a?(Time)
      }
    ) do
      @article.track_view(ip: "8.8.8.8")
    end
  end

  def test_async_mode_no_db_record_immediately
    Footprinted.configuration.async = true

    @article.track_view(ip: "8.8.8.8")
    assert_equal 0, Footprinted::Footprint.count
  end

  def test_switching_between_sync_and_async
    # Sync mode
    Footprinted.configuration.async = false
    result = @article.track_view(ip: "1.1.1.1")
    assert_instance_of Footprinted::Footprint, result
    assert result.persisted?
    assert_equal 1, Footprinted::Footprint.count

    # Switch to async
    Footprinted.configuration.async = true
    @article.track_view(ip: "2.2.2.2")
    # Still only 1 because async doesn't create immediately
    assert_equal 1, Footprinted::Footprint.count

    # Switch back to sync
    Footprinted.configuration.async = false
    result2 = @article.track_view(ip: "3.3.3.3")
    assert result2.persisted?
    assert_equal 2, Footprinted::Footprint.count
  end

  # -- Generic track() with symbol vs string --

  def test_track_with_symbol_event_type
    result = @article.track(:activation, ip: "8.8.8.8")
    assert_equal "activation", result.event_type
  end

  def test_track_with_string_event_type
    result = @article.track("activation", ip: "8.8.8.8")
    assert_equal "activation", result.event_type
  end

  def test_generic_track_async_mode
    Footprinted.configuration.async = true

    assert_enqueued_with(job: Footprinted::TrackJob) do
      @article.track(:custom_event, ip: "8.8.8.8")
    end
  end

  def test_generic_track_async_no_record_immediately
    Footprinted.configuration.async = true

    @article.track("custom_event", ip: "8.8.8.8")
    assert_equal 0, Footprinted::Footprint.count
  end

  # -- has_trackable track method with async serialization --

  def test_has_trackable_async_passes_correct_class_and_id
    Footprinted.configuration.async = true

    assert_enqueued_with(
      job: Footprinted::TrackJob,
      args: ->(args) {
        args[0] == "Article" && args[1] == @article.id
      }
    ) do
      @article.track_view(ip: "8.8.8.8")
    end
  end

  def test_has_trackable_async_with_metadata_and_performer
    Footprinted.configuration.async = true

    assert_enqueued_with(
      job: Footprinted::TrackJob,
      args: ->(args) {
        attrs = args[2]
        attrs[:ip] == "8.8.8.8" &&
          attrs[:event_type] == "view" &&
          attrs[:metadata] == { browser: "Firefox" }
      }
    ) do
      @article.track_view(
        ip: "8.8.8.8",
        metadata: { browser: "Firefox" }
      )
    end
  end

  # -- Geo error graceful degradation --

  def test_async_track_still_enqueues_job_when_geo_lookup_fails
    Footprinted.configuration.async = true

    # Stub Trackdown to raise an error (e.g., private IP rejected)
    stub_trackdown_locate_error("Private IP addresses are not allowed")

    # Should still enqueue the job without geo data
    assert_enqueued_with(
      job: Footprinted::TrackJob,
      args: ->(args) {
        attrs = args[2]
        attrs[:ip] == "192.168.1.1" &&
          attrs[:event_type] == "view" &&
          attrs[:metadata] == { sdk_version: "1.0" } &&
          attrs[:country_code].nil?  # No geo data due to error
      }
    ) do
      @article.track_view(
        ip: "192.168.1.1",
        request: Object.new,
        metadata: { sdk_version: "1.0" }
      )
    end
  end

  private

  def parsed_metadata(footprint)
    metadata = footprint.metadata
    metadata.is_a?(String) ? JSON.parse(metadata) : metadata
  end

  def stub_trackdown_locate_error(message)
    verbose_was, $VERBOSE = $VERBOSE, nil
    Trackdown.define_singleton_method(:locate) do |ip, request: nil|
      raise Trackdown::Error, message
    end
  ensure
    $VERBOSE = verbose_was
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
