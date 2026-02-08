# frozen_string_literal: true

require "test_helper"

class Footprinted::VersionTest < ActiveSupport::TestCase
  def test_has_version_number
    refute_nil Footprinted::VERSION
  end

  def test_version_is_correct
    assert_equal "0.2.0", Footprinted::VERSION
  end

  def test_version_is_a_string
    assert_instance_of String, Footprinted::VERSION
  end

  def test_version_is_frozen
    assert Footprinted::VERSION.frozen?
  end

  def test_version_follows_semver_format
    assert_match(/\A\d+\.\d+\.\d+\z/, Footprinted::VERSION)
  end
end
