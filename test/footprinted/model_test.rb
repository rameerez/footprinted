# frozen_string_literal: true

require "test_helper"

class FootprintedModelTest < Minitest::Test
  include ActiveSupport::Testing::TimeHelpers

  def setup
    TrackdownStub.enable!
  end

  def teardown
    TrackdownStub.disable!
  end

  def test_includes_trackable_activities_association
    profile = Profile.create!(name: "A")
    assert_respond_to profile, :trackable_activities
  end

  class UserWithViews < Profile
    self.table_name = "profiles"
    has_trackable :profile_views
  end

  def test_has_trackable_defines_association_and_tracking_method
    profile = UserWithViews.create!(name: "X")
    assert_respond_to profile, :profile_views
    assert_respond_to profile, :track_profile_view

    performer = Account.create!(email: "p@example.com")
    record = profile.track_profile_view(ip: "1.2.3.4", performer: performer)

    assert_instance_of Footprinted::TrackableActivity, record
    assert_equal "profile_view", record.activity_type
    assert_equal performer, record.performer
    assert_equal profile.id, record.trackable_id
    assert_equal "Profile", record.trackable_type
    assert record.trackable.is_a?(Profile)
    assert_equal "US", record.country
    assert_equal "New York", record.city
  end

  class UserWithDownloads < Profile
    self.table_name = "profiles"
    has_trackable :downloads
  end

  def test_custom_tracking_method_raises_on_validation_error
    profile = UserWithDownloads.create!(name: "X")
    assert_raises ActiveRecord::RecordInvalid do
      profile.track_download(ip: nil)
    end
  end

  def test_fallback_track_activity_creates_record_with_activity_type_and_performer
    profile = Profile.create!(name: "Fallback")
    performer = Account.create!(email: "p@example.com")

    record = profile.track_activity(ip: "5.6.7.8", performer: performer, activity_type: "test")

    assert record.persisted?
    assert_equal "test", record.activity_type
    assert_equal performer, record.performer
    assert_equal profile, record.trackable
  end

  class UserWithViewsDependent < Profile
    self.table_name = "profiles"
    has_trackable :views
  end

  def test_dependent_destroy_cascades
    profile = UserWithViewsDependent.create!(name: "X")
    profile.track_view(ip: "9.9.9.9")
    assert_equal 1, Footprinted::TrackableActivity.count

    profile.destroy
    assert_equal 0, Footprinted::TrackableActivity.count
  end
end