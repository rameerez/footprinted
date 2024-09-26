# frozen_string_literal: true

module Footprinted
  class Railtie < Rails::Railtie
    initializer "footprinted.initialize" do
      ActiveSupport.on_load(:active_record) do
        extend Footprinted::Model
      end
    end

    rake_tasks do
      load "tasks/footprinted_tasks.rake"
    end

    generators do
      require "generators/footprinted/install_generator"
    end
  end
end
