# frozen_string_literal: true

require_relative "footprinted/version"
require_relative "footprinted/configuration"
require_relative "footprinted/model"
require_relative "footprinted/trackable_activity"

module Footprinted
  class Error < StandardError; end

  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  def self.reset
    @configuration = Configuration.new
  end
end

require "footprinted/railtie" if defined?(Rails)
