# frozen_string_literal: true

require "test_helper"

class Footprinted::ConfigurationTest < ActiveSupport::TestCase
  def setup
    super
  end

  # -- Default values --

  def test_default_async_is_false
    config = Footprinted::Configuration.new
    assert_equal false, config.async
  end

  # -- Setter --

  def test_async_can_be_set_to_true
    config = Footprinted::Configuration.new
    config.async = true
    assert_equal true, config.async
  end

  def test_async_can_be_toggled_back_to_false
    config = Footprinted::Configuration.new
    config.async = true
    config.async = false
    assert_equal false, config.async
  end

  # -- Footprinted.configure --

  def test_configure_yields_configuration
    Footprinted.configure do |config|
      assert_instance_of Footprinted::Configuration, config
    end
  end

  def test_configure_sets_async
    Footprinted.configure do |config|
      config.async = true
    end
    assert_equal true, Footprinted.configuration.async
  end

  # -- Footprinted.configuration memoization --

  def test_configuration_returns_same_instance
    config1 = Footprinted.configuration
    config2 = Footprinted.configuration
    assert_same config1, config2
  end

  def test_configuration_returns_configuration_instance
    assert_instance_of Footprinted::Configuration, Footprinted.configuration
  end

  # -- Footprinted.reset --

  def test_reset_resets_to_defaults
    Footprinted.configure do |config|
      config.async = true
    end
    assert_equal true, Footprinted.configuration.async

    Footprinted.reset
    assert_equal false, Footprinted.configuration.async
  end

  def test_reset_creates_new_configuration_instance
    old_config = Footprinted.configuration
    Footprinted.reset
    new_config = Footprinted.configuration
    refute_same old_config, new_config
  end

  # -- Footprinted.configuration= writer --

  def test_configuration_writer
    new_config = Footprinted::Configuration.new
    new_config.async = true
    Footprinted.configuration = new_config
    assert_equal true, Footprinted.configuration.async
  end
end
