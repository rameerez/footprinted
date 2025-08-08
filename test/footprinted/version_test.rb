# frozen_string_literal: true

require "test_helper"

class FootprintedVersionTest < Minitest::Test
  def test_version_present
    refute_nil ::Footprinted::VERSION
    assert_match(/\A\d+\.\d+\.\d+\z/, ::Footprinted::VERSION)
  end
end