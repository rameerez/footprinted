# frozen_string_literal: true

module Footprinted
  class Configuration
    attr_accessor :ip_lookup_service

    def initialize
      @ip_lookup_service = :trackdown
    end
  end
end
