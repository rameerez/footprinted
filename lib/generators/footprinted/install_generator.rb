# frozen_string_literal: true

require "rails/generators/base"
require "rails/generators/active_record"

module Footprinted
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      def create_migration_file
        migration_template "create_footprinted_footprints.rb.erb",
                           File.join(db_migrate_path, "create_footprinted_footprints.rb")
      end

      def create_initializer
        template "footprinted.rb", "config/initializers/footprinted.rb"
      end

      def display_post_install_message
        say "\n🎉 The `footprinted` gem has been successfully installed!", :green
        say "\nTo complete the setup:"
        say "  1. Run `rails db:migrate` to create the footprints table."
        say "     ⚠️  You must run migrations before starting your app!", :yellow
        say "\n  2. Add `include Footprinted::Model` to any model you want to track:"
        say "       class Product < ApplicationRecord"
        say "         include Footprinted::Model"
        say "       end"
        say "\n  3. Create footprints from your controllers or services:"
        say "       product.footprints.create!("
        say "         ip: request.remote_ip,"
        say "         event_type: 'page_view',"
        say "         occurred_at: Time.current"
        say "       )"
        say "\nSee the footprinted README for detailed usage and examples.", :cyan
        say "Happy tracking! 👣\n", :green
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::STRING.to_f}]"
      end
    end
  end
end
