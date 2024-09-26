# frozen_string_literal: true

module Footprinted
  class TrackableActivity < ActiveRecord::Base
    belongs_to :trackable, polymorphic: true
    belongs_to :user, optional: true

    before_save :set_ip_fields

    private

    def set_ip_fields
      return unless ip.present?

      case Footprinted.configuration.ip_lookup_service
      when :trackdown
        location = Trackdown.locate(ip.to_s)
        self.country = location.country_code
        self.city = location.city
      # Add other IP lookup services here if needed
      else
        raise Footprinted::Error, "Unknown IP lookup service: #{Footprinted.configuration.ip_lookup_service}"
      end
    end
  end
end
