# frozen_string_literal: true

require "test_helper"

class FootprintedConfigurationTest < Minitest::Test
  def setup
    Footprinted.reset
  end

  def test_configuration_returns_configuration_instance
    assert_instance_of Footprinted::Configuration, Footprinted.configuration
  end

  def test_configure_yields_configuration
    yielded = nil
    Footprinted.configure { |c| yielded = c }
    assert_instance_of Footprinted::Configuration, yielded
  end

  def test_reset_creates_new_configuration
    original = Footprinted.configuration
    Footprinted.configure { |_c| }
    Footprinted.reset
    refute_same original, Footprinted.configuration
  end
end