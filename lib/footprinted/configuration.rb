# frozen_string_literal: true

module Footprinted
  class Configuration
    attr_accessor :async

    def initialize
      @async = false
    end
  end
end
