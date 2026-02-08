# frozen_string_literal: true

SimpleCov.start do
  formatter SimpleCov::Formatter::SimpleFormatter

  add_filter "/test/"

  track_files "{lib,app}/**/*.rb"

  enable_coverage :branch

  minimum_coverage line: 80, branch: 65

  command_name "Job #{ENV['TEST_ENV_NUMBER']}" if ENV['TEST_ENV_NUMBER']
end

SimpleCov.at_exit do
  SimpleCov.result.format!
  puts "\n" + "=" * 60
  puts "COVERAGE SUMMARY"
  puts "=" * 60
  puts "Line Coverage:   #{SimpleCov.result.covered_percent.round(2)}%"
  puts "Branch Coverage: #{SimpleCov.result.coverage_statistics[:branch]&.percent&.round(2) || 'N/A'}%"
  puts "=" * 60
end
