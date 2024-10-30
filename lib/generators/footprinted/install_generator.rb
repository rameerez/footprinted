# frozen_string_literal: true

require 'rails/generators/base'
require 'rails/generators/active_record'

module Footprinted
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      def self.next_migration_number(dir)
        ActiveRecord::Generators::Base.next_migration_number(dir)
      end

      def create_migration_file
        migration_template 'create_footprinted_trackable_activities.rb.erb', File.join(db_migrate_path, "create_footprinted_trackable_activities.rb")
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::STRING.to_f}]"
      end

    end
  end
end
