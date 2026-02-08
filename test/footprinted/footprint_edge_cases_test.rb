# frozen_string_literal: true

require "test_helper"

class Footprinted::FootprintEdgeCasesTest < ActiveSupport::TestCase
  def setup
    super
    @article = Article.create!(title: "Test Article")
    @user = User.create!(name: "Test User")
    stub_trackdown_locate(DEFAULT_LOCATION)
  end

  # -- Metadata edge cases --

  def test_metadata_empty_hash
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      metadata: {}
    )
    metadata = parsed_metadata(footprint)
    assert_equal({}, metadata)
  end

  def test_metadata_deeply_nested_hash
    deep = { level1: { level2: { level3: { level4: "deep_value" } } } }
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      metadata: deep
    )
    metadata = parsed_metadata(footprint)
    assert_equal "deep_value", metadata["level1"]["level2"]["level3"]["level4"]
  end

  def test_metadata_with_special_characters
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      metadata: { key: "value with <html> & \"quotes\" and 'apostrophes'" }
    )
    metadata = parsed_metadata(footprint)
    assert_equal "value with <html> & \"quotes\" and 'apostrophes'", metadata["key"]
  end

  def test_metadata_with_unicode
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      metadata: { greeting: "Hola! Bonjour! Hej!", emoji_test: "test" }
    )
    metadata = parsed_metadata(footprint)
    assert_equal "Hola! Bonjour! Hej!", metadata["greeting"]
  end

  def test_metadata_with_nil_values_in_hash
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      metadata: { present_key: "value", nil_key: nil }
    )
    metadata = parsed_metadata(footprint)
    assert_equal "value", metadata["present_key"]
    assert_nil metadata["nil_key"]
    assert metadata.key?("nil_key")
  end

  def test_metadata_with_large_payload
    large_metadata = {}
    100.times { |i| large_metadata["key_#{i}"] = "value_#{i}" * 10 }
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      metadata: large_metadata
    )
    metadata = parsed_metadata(footprint)
    assert_equal 100, metadata.keys.size
    assert_equal "value_99" * 10, metadata["key_99"]
  end

  def test_metadata_with_numeric_values
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      metadata: { count: 42, ratio: 3.14, negative: -1 }
    )
    metadata = parsed_metadata(footprint)
    assert_equal 42, metadata["count"]
    assert_in_delta 3.14, metadata["ratio"], 0.001
    assert_equal(-1, metadata["negative"])
  end

  def test_metadata_with_boolean_values
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      metadata: { active: true, deleted: false }
    )
    metadata = parsed_metadata(footprint)
    assert_equal true, metadata["active"]
    assert_equal false, metadata["deleted"]
  end

  def test_metadata_with_array_values
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      metadata: { tags: ["ruby", "rails", "gem"], counts: [1, 2, 3] }
    )
    metadata = parsed_metadata(footprint)
    assert_equal ["ruby", "rails", "gem"], metadata["tags"]
    assert_equal [1, 2, 3], metadata["counts"]
  end

  # -- IP edge cases --

  def test_ipv6_address
    footprint = Footprinted::Footprint.create!(
      ip: "2001:0db8:85a3:0000:0000:8a2e:0370:7334",
      event_type: "view",
      trackable: @article
    )
    assert_equal "2001:0db8:85a3:0000:0000:8a2e:0370:7334", footprint.ip
  end

  def test_ipv6_short_format
    footprint = Footprinted::Footprint.create!(
      ip: "::1",
      event_type: "view",
      trackable: @article
    )
    assert_equal "::1", footprint.ip
  end

  def test_localhost_ipv4
    footprint = Footprinted::Footprint.create!(
      ip: "127.0.0.1",
      event_type: "view",
      trackable: @article
    )
    assert_equal "127.0.0.1", footprint.ip
  end

  def test_private_ip_ranges
    %w[10.0.0.1 172.16.0.1 192.168.1.1].each do |private_ip|
      footprint = Footprinted::Footprint.create!(
        ip: private_ip,
        event_type: "view",
        trackable: @article
      )
      assert_equal private_ip, footprint.ip
    end
  end

  def test_ip_with_edge_format
    footprint = Footprinted::Footprint.create!(
      ip: "0.0.0.0",
      event_type: "view",
      trackable: @article
    )
    assert_equal "0.0.0.0", footprint.ip
  end

  def test_ipv4_mapped_ipv6
    footprint = Footprinted::Footprint.create!(
      ip: "::ffff:192.168.1.1",
      event_type: "view",
      trackable: @article
    )
    assert_equal "::ffff:192.168.1.1", footprint.ip
  end

  # -- Event type edge cases --

  def test_very_long_event_type
    long_type = "a" * 255
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: long_type,
      trackable: @article
    )
    assert_equal long_type, footprint.event_type
  end

  def test_event_type_with_special_characters
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "user.login-attempt_v2",
      trackable: @article
    )
    assert_equal "user.login-attempt_v2", footprint.event_type
  end

  def test_event_type_whitespace_only_is_invalid
    footprint = Footprinted::Footprint.new(
      ip: "1.2.3.4",
      event_type: "   ",
      trackable: @article
    )
    # Whitespace-only may pass the presence check since presence validates non-blank
    # but Rails presence validator rejects blank strings
    refute footprint.valid?
  end

  # -- Trackdown failure modes --

  def test_trackdown_runtime_error_rescued
    stub_trackdown_locate_with_exception(RuntimeError, "runtime failure")
    footprint = Footprinted::Footprint.create!(
      ip: "8.8.8.8",
      event_type: "view",
      trackable: @article
    )
    assert_nil footprint.country_code
    assert footprint.persisted?
  end

  def test_trackdown_standard_error_rescued
    stub_trackdown_locate_with_exception(StandardError, "standard failure")
    footprint = Footprinted::Footprint.create!(
      ip: "8.8.8.8",
      event_type: "view",
      trackable: @article
    )
    assert_nil footprint.country_code
    assert footprint.persisted?
  end

  def test_trackdown_timeout_error_rescued
    stub_trackdown_locate_with_exception(Timeout::Error, "timeout")
    footprint = Footprinted::Footprint.create!(
      ip: "8.8.8.8",
      event_type: "view",
      trackable: @article
    )
    assert_nil footprint.country_code
    assert footprint.persisted?
  end

  def test_trackdown_socket_error_rescued
    stub_trackdown_locate_with_exception(SocketError, "socket error")
    footprint = Footprinted::Footprint.create!(
      ip: "8.8.8.8",
      event_type: "view",
      trackable: @article
    )
    assert_nil footprint.country_code
    assert footprint.persisted?
  end

  def test_trackdown_returning_partial_data
    partial_location = MockLocationResult.new(
      country_code: "US",
      country_name: "United States",
      city: nil,
      region: nil,
      continent: nil,
      timezone: nil,
      latitude: nil,
      longitude: nil
    )
    stub_trackdown_locate(partial_location)

    footprint = Footprinted::Footprint.create!(
      ip: "8.8.8.8",
      event_type: "view",
      trackable: @article
    )
    assert_equal "US", footprint.country_code
    assert_equal "United States", footprint.country_name
    assert_nil footprint.city
    assert_nil footprint.region
    assert_nil footprint.latitude
    assert_nil footprint.longitude
  end

  # -- Geolocation skip when country_code already set --

  def test_skip_geolocation_preserves_all_existing_fields
    footprint = Footprinted::Footprint.create!(
      ip: "8.8.8.8",
      event_type: "view",
      trackable: @article,
      country_code: "DE",
      country_name: "Germany",
      city: "Berlin",
      region: "Berlin",
      continent: "EU",
      timezone: "Europe/Berlin",
      latitude: 52.5200,
      longitude: 13.4050
    )
    # Verify Trackdown result did NOT overwrite any fields
    assert_equal "DE", footprint.country_code
    assert_equal "Germany", footprint.country_name
    assert_equal "Berlin", footprint.city
    assert_equal "Berlin", footprint.region
    assert_equal "EU", footprint.continent
    assert_equal "Europe/Berlin", footprint.timezone
    assert_in_delta 52.5200, footprint.latitude.to_f, 0.001
    assert_in_delta 13.4050, footprint.longitude.to_f, 0.001
  end

  # -- Performer association edge cases --

  def test_performer_can_be_set
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      performer: @user
    )
    assert_equal @user, footprint.performer
  end

  def test_performer_can_be_changed
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      performer: @user
    )
    another_user = User.create!(name: "Another User")
    footprint.update!(performer: another_user)
    assert_equal another_user, footprint.reload.performer
  end

  def test_performer_can_be_nil
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      performer: nil
    )
    assert_nil footprint.performer
  end

  def test_performer_set_then_cleared
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      performer: @user
    )
    footprint.update!(performer: nil)
    assert_nil footprint.reload.performer
  end

  # -- occurred_at edge cases --

  def test_occurred_at_past_date
    past_time = Time.new(2020, 1, 1, 0, 0, 0, "+00:00")
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      occurred_at: past_time
    )
    assert_equal past_time.to_i, footprint.occurred_at.to_i
  end

  def test_occurred_at_future_date
    future_time = Time.new(2030, 12, 31, 23, 59, 59, "+00:00")
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      occurred_at: future_time
    )
    assert_equal future_time.to_i, footprint.occurred_at.to_i
  end

  def test_occurred_at_with_timezone
    # Pacific time
    pacific_time = Time.new(2025, 6, 15, 12, 0, 0, "-07:00")
    footprint = Footprinted::Footprint.create!(
      ip: "1.2.3.4",
      event_type: "view",
      trackable: @article,
      occurred_at: pacific_time
    )
    assert_equal pacific_time.to_i, footprint.occurred_at.to_i
  end

  # -- Concurrent footprint creation --

  def test_multiple_footprints_for_same_trackable
    10.times do |i|
      Footprinted::Footprint.create!(
        ip: "1.2.3.#{i}",
        event_type: "view",
        trackable: @article
      )
    end
    assert_equal 10, @article.footprints.count
  end

  # -- Scope chaining combinations --

  def test_scope_chaining_last_days_with_by_event
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: 2.days.ago)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "download", trackable: @article, occurred_at: 2.days.ago)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: 10.days.ago)

    results = Footprinted::Footprint.last_days(5).by_event("view")
    assert_equal 1, results.count
  end

  def test_scope_chaining_between_with_by_country
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: "US", occurred_at: 3.days.ago)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: "DE", occurred_at: 3.days.ago)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, country_code: "US", occurred_at: 20.days.ago)

    results = Footprinted::Footprint.between(7.days.ago, Time.current).by_country("US")
    assert_equal 1, results.count
  end

  def test_scope_performed_by_with_by_event
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, performer: @user)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "download", trackable: @article, performer: @user)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article)

    results = Footprinted::Footprint.performed_by(@user).by_event("view")
    assert_equal 1, results.count
  end

  def test_scope_recent_with_last_days
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: 20.days.ago)
    recent_1 = Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: 1.day.ago)
    Footprinted::Footprint.create!(ip: "1.1.1.1", event_type: "view", trackable: @article, occurred_at: 2.days.ago)

    results = Footprinted::Footprint.last_days(5).recent
    assert_equal 2, results.count
    assert_equal recent_1.id, results.first.id
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

  def stub_trackdown_locate_with_exception(exception_class, message)
    verbose_was, $VERBOSE = $VERBOSE, nil
    Trackdown.define_singleton_method(:locate) do |ip, request: nil|
      raise exception_class, message
    end
  ensure
    $VERBOSE = verbose_was
  end
end
