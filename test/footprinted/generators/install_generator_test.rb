# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/footprinted/install_generator"

class FootprintedInstallGeneratorTest < Rails::Generators::TestCase
  tests Footprinted::Generators::InstallGenerator
  destination File.expand_path("../../tmp/generator", __dir__)

  setup :prepare_destination

  def test_creates_migration_file
    run_generator

    files = Dir[File.join(destination_root, "db/migrate/*.rb")]
    assert_equal 1, files.size

    content = File.read(files.first)
    assert_includes content, "create_table :trackable_activities"
    assert_includes content, "t.inet :ip"
    assert_includes content, ":trackable, polymorphic: true"
    assert_includes content, ":performer, polymorphic: true"
    assert_includes content, "t.text :activity_type, null: false"
  end
end