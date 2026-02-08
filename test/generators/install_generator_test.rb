# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/footprinted/install_generator"

class Footprinted::Generators::InstallGeneratorTest < Rails::Generators::TestCase
  tests Footprinted::Generators::InstallGenerator
  destination File.expand_path("../../tmp", __dir__)

  setup do
    prepare_destination
  end

  def test_creates_migration_file
    run_generator
    assert_migration "db/migrate/create_footprinted_footprints.rb"
  end

  def test_creates_initializer_file
    run_generator
    assert_file "config/initializers/footprinted.rb"
  end

  def test_migration_contains_footprints_table
    run_generator
    assert_migration "db/migrate/create_footprinted_footprints.rb" do |migration|
      assert_match(/create_table :footprints/, migration)
    end
  end

  def test_migration_contains_ip_column
    run_generator
    assert_migration "db/migrate/create_footprinted_footprints.rb" do |migration|
      assert_match(/:ip/, migration)
    end
  end

  def test_migration_contains_geo_columns
    run_generator
    assert_migration "db/migrate/create_footprinted_footprints.rb" do |migration|
      assert_match(/:country_code/, migration)
      assert_match(/:country_name/, migration)
      assert_match(/:city/, migration)
      assert_match(/:region/, migration)
      assert_match(/:continent/, migration)
      assert_match(/:timezone/, migration)
      assert_match(/:latitude/, migration)
      assert_match(/:longitude/, migration)
    end
  end

  def test_migration_contains_polymorphic_references
    run_generator
    assert_migration "db/migrate/create_footprinted_footprints.rb" do |migration|
      assert_match(/:trackable, polymorphic: true/, migration)
      assert_match(/:performer, polymorphic: true/, migration)
    end
  end

  def test_migration_contains_event_type_and_metadata
    run_generator
    assert_migration "db/migrate/create_footprinted_footprints.rb" do |migration|
      assert_match(/:event_type/, migration)
      assert_match(/:metadata/, migration)
      assert_match(/:occurred_at/, migration)
    end
  end

  def test_migration_contains_indexes
    run_generator
    assert_migration "db/migrate/create_footprinted_footprints.rb" do |migration|
      assert_match(/idx_footprints_trackable_event_time/, migration)
      assert_match(/add_index :footprints, :event_type/, migration)
      assert_match(/add_index :footprints, :occurred_at/, migration)
      assert_match(/add_index :footprints, :country_code/, migration)
    end
  end

  def test_initializer_contains_configure_block
    run_generator
    assert_file "config/initializers/footprinted.rb" do |initializer|
      assert_match(/Footprinted.configure/, initializer)
    end
  end
end
