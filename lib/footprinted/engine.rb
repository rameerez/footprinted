# frozen_string_literal: true

module Footprinted
  class Engine < Rails::Engine
    initializer "footprinted.initialize" do
      ActiveSupport.on_load(:active_record) do
        extend Footprinted::Model
      end
    end

    generators do
      require "generators/footprinted/install_generator"
    end
  end
end
