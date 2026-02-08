# frozen_string_literal: true

require "test_helper"

class Footprinted::TrackJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    super
    @article = Article.create!(title: "Test Article")
    @user = User.create!(name: "Test User")
    stub_trackdown_locate(DEFAULT_LOCATION)
  end

  def test_performs_and_creates_footprint
    perform_enqueued_jobs do
      Footprinted::TrackJob.perform_later(
        "Article", @article.id,
        { ip: "8.8.8.8", event_type: "view", occurred_at: Time.current.iso8601 }
      )
    end

    assert_equal 1, Footprinted::Footprint.count
    footprint = Footprinted::Footprint.last
    assert_equal "8.8.8.8", footprint.ip
    assert_equal "view", footprint.event_type
    assert_equal @article, footprint.trackable
  end

  def test_handles_missing_trackable_gracefully
    perform_enqueued_jobs do
      Footprinted::TrackJob.perform_later(
        "Article", 999999,
        { ip: "8.8.8.8", event_type: "view", occurred_at: Time.current.iso8601 }
      )
    end

    assert_equal 0, Footprinted::Footprint.count
  end

  def test_parses_occurred_at_from_iso8601_string
    time = Time.new(2025, 3, 15, 10, 30, 0, "+00:00")

    perform_enqueued_jobs do
      Footprinted::TrackJob.perform_later(
        "Article", @article.id,
        { ip: "8.8.8.8", event_type: "view", occurred_at: time.iso8601 }
      )
    end

    footprint = Footprinted::Footprint.last
    assert_equal time.to_i, footprint.occurred_at.to_i
  end

  def test_works_with_string_keys
    perform_enqueued_jobs do
      Footprinted::TrackJob.perform_later(
        "Article", @article.id,
        { "ip" => "8.8.8.8", "event_type" => "view", "occurred_at" => Time.current.iso8601 }
      )
    end

    assert_equal 1, Footprinted::Footprint.count
    footprint = Footprinted::Footprint.last
    assert_equal "8.8.8.8", footprint.ip
    assert_equal "view", footprint.event_type
  end

  def test_works_with_symbol_keys
    perform_enqueued_jobs do
      Footprinted::TrackJob.perform_later(
        "Article", @article.id,
        { ip: "8.8.8.8", event_type: "view", occurred_at: Time.current.iso8601 }
      )
    end

    assert_equal 1, Footprinted::Footprint.count
  end

  def test_creates_footprint_associated_with_correct_trackable
    article2 = Article.create!(title: "Second Article")

    perform_enqueued_jobs do
      Footprinted::TrackJob.perform_later(
        "Article", article2.id,
        { ip: "8.8.8.8", event_type: "view", occurred_at: Time.current.iso8601 }
      )
    end

    footprint = Footprinted::Footprint.last
    assert_equal article2, footprint.trackable
  end

  def test_queued_on_default_queue
    assert_equal "default", Footprinted::TrackJob.new.queue_name
  end

  def test_perform_with_metadata
    perform_enqueued_jobs do
      Footprinted::TrackJob.perform_later(
        "Article", @article.id,
        { ip: "8.8.8.8", event_type: "view", metadata: { browser: "Firefox" }, occurred_at: Time.current.iso8601 }
      )
    end

    footprint = Footprinted::Footprint.last
    metadata = footprint.metadata
    metadata = JSON.parse(metadata) if metadata.is_a?(String)
    assert_equal "Firefox", metadata["browser"]
  end

  def test_perform_directly
    Footprinted::TrackJob.new.perform(
      "Article", @article.id,
      { "ip" => "8.8.8.8", "event_type" => "view", "occurred_at" => Time.current.iso8601 }
    )

    assert_equal 1, Footprinted::Footprint.count
  end

  def test_perform_directly_with_missing_trackable_returns_nil
    result = Footprinted::TrackJob.new.perform(
      "Article", 999999,
      { "ip" => "8.8.8.8", "event_type" => "view", "occurred_at" => Time.current.iso8601 }
    )

    assert_nil result
    assert_equal 0, Footprinted::Footprint.count
  end

  def test_perform_with_non_string_occurred_at
    time = Time.new(2025, 3, 15, 10, 30, 0, "+00:00")

    # When occurred_at is not a string (e.g. already a Time), it should pass through
    Footprinted::TrackJob.new.perform(
      "Article", @article.id,
      { "ip" => "8.8.8.8", "event_type" => "view", "occurred_at" => time }
    )

    assert_equal 1, Footprinted::Footprint.count
    footprint = Footprinted::Footprint.last
    assert_equal time.to_i, footprint.occurred_at.to_i
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
