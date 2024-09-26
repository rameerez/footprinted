# frozen_string_literal: true

require 'rails/generators/base'

module Footprinted
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def create_initializer_file
        template 'footprinted.rb', 'config/initializers/footprinted.rb'
      end

      def create_migration
        generate "migration", "CreateTrackableActivities ip:inet country:string city:string trackable:references{polymorphic} user:references activity_type:string"
      end
    end
  end
end
