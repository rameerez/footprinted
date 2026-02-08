# frozen_string_literal: true

require "test_helper"

class Footprinted::TrackJobEdgeCasesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    super
    @article = Article.create!(title: "Test Article")
    @user = User.create!(name: "Test User")
    stub_trackdown_locate(DEFAULT_LOCATION)
  end

  # -- Non-existent trackable type --

  def test_job_with_non_existent_trackable_type_raises
    assert_raises(NameError) do
      Footprinted::TrackJob.new.perform(
        "NonExistentModel", 1,
        { "ip" => "8.8.8.8", "event_type" => "view", "occurred_at" => Time.current.iso8601 }
      )
    end
  end

  # -- Job with invalid attributes --

  def test_job_with_missing_ip_raises_validation_error
    assert_raises(ActiveRecord::RecordInvalid) do
      Footprinted::TrackJob.new.perform(
        "Article", @article.id,
        { "ip" => nil, "event_type" => "view", "occurred_at" => Time.current.iso8601 }
      )
    end
  end

  def test_job_with_missing_event_type_raises_validation_error
    assert_raises(ActiveRecord::RecordInvalid) do
      Footprinted::TrackJob.new.perform(
        "Article", @article.id,
        { "ip" => "8.8.8.8", "event_type" => nil, "occurred_at" => Time.current.iso8601 }
      )
    end
  end

  # -- Job idempotency --

  def test_job_creates_separate_records_each_run
    attrs = { "ip" => "8.8.8.8", "event_type" => "view", "occurred_at" => Time.current.iso8601 }

    Footprinted::TrackJob.new.perform("Article", @article.id, attrs)
    Footprinted::TrackJob.new.perform("Article", @article.id, attrs)

    assert_equal 2, Footprinted::Footprint.count
  end

  # -- Job with metadata --

  def test_job_preserves_rich_metadata
    rich_metadata = {
      "sdk_version" => "0.4.0",
      "os_name" => "macOS",
      "os_version" => "15.2",
      "platform" => "macOS",
      "device_model" => "Mac15,3",
      "app_version" => "2.1.0",
      "locale" => "en_US",
      "timezone" => "America/Los_Angeles"
    }

    Footprinted::TrackJob.new.perform(
      "Article", @article.id,
      { "ip" => "8.8.8.8", "event_type" => "activation", "metadata" => rich_metadata, "occurred_at" => Time.current.iso8601 }
    )

    footprint = Footprinted::Footprint.last
    metadata = footprint.metadata
    metadata = JSON.parse(metadata) if metadata.is_a?(String)

    assert_equal "0.4.0", metadata["sdk_version"]
    assert_equal "macOS", metadata["os_name"]
    assert_equal "Mac15,3", metadata["device_model"]
  end

  # -- Job with deleted trackable --

  def test_job_with_deleted_trackable_is_silently_skipped
    article_id = @article.id
    @article.destroy

    result = Footprinted::TrackJob.new.perform(
      "Article", article_id,
      { "ip" => "8.8.8.8", "event_type" => "view", "occurred_at" => Time.current.iso8601 }
    )

    assert_nil result
    assert_equal 0, Footprinted::Footprint.count
  end

  # -- Job via perform_later round-trip --

  def test_job_full_round_trip_with_rich_attrs
    Footprinted.configuration.async = true

    perform_enqueued_jobs do
      @article.track(:activation, ip: "8.8.4.4", metadata: { sdk_version: "1.0" })
    end

    assert_equal 1, Footprinted::Footprint.count
    footprint = Footprinted::Footprint.last
    assert_equal "8.8.4.4", footprint.ip
    assert_equal "activation", footprint.event_type
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
end
