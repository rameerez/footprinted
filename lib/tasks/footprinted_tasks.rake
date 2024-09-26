# frozen_string_literal: true

namespace :footprinted do
  desc "Print the current Footprinted configuration"
  task configuration: :environment do
    puts "Current Footprinted configuration:"
    puts "IP Lookup Service: #{Footprinted.configuration.ip_lookup_service}"
  end
end
