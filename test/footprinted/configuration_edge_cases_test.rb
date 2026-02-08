# frozen_string_literal: true

require "test_helper"

class Footprinted::ConfigurationEdgeCasesTest < ActiveSupport::TestCase
  def setup
    super
  end

  # -- Thread safety of configuration --

  def test_configuration_is_accessible_from_threads
    Footprinted.configure do |config|
      config.async = true
    end

    results = []
    threads = 5.times.map do
      Thread.new do
        results << Footprinted.configuration.async
      end
    end
    threads.each(&:join)

    assert_equal 5, results.size
    assert results.all? { |r| r == true }
  end

  # -- Multiple configure blocks --

  def test_multiple_configure_blocks_accumulate
    Footprinted.configure do |config|
      config.async = true
    end

    # Second configure call should modify the same instance
    Footprinted.configure do |config|
      # async should still be true from previous block
      assert_equal true, config.async
    end
  end

  def test_multiple_configure_blocks_override
    Footprinted.configure do |config|
      config.async = true
    end
    assert_equal true, Footprinted.configuration.async

    Footprinted.configure do |config|
      config.async = false
    end
    assert_equal false, Footprinted.configuration.async
  end

  # -- Configuration writer --

  def test_configuration_writer_replaces_instance
    config1 = Footprinted.configuration
    new_config = Footprinted::Configuration.new
    new_config.async = true

    Footprinted.configuration = new_config
    refute_same config1, Footprinted.configuration
    assert_equal true, Footprinted.configuration.async
  end

  # -- Reset after configure --

  def test_reset_after_multiple_configures
    Footprinted.configure { |c| c.async = true }
    Footprinted.configure { |c| c.async = false }
    Footprinted.configure { |c| c.async = true }

    Footprinted.reset
    assert_equal false, Footprinted.configuration.async
  end

  # -- Default configuration state --

  def test_fresh_configuration_has_all_defaults
    config = Footprinted::Configuration.new
    assert_equal false, config.async
  end
end
