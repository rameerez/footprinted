# frozen_string_literal: true

require "test_helper"

class FootprintedRailtieTest < Minitest::Test
  def test_railtie_loads
    require "footprinted/railtie"
    assert defined?(Footprinted::Railtie)
  end

  def test_generator_registered
    require "footprinted/railtie"
    assert defined?(::Footprinted::Generators::InstallGenerator)
  end
end