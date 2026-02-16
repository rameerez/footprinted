# frozen_string_literal: true

module Footprinted
  class TrackJob < ActiveJob::Base
    queue_as :default

    def perform(trackable_type, trackable_id, attributes)
      trackable = trackable_type.constantize.find_by(id: trackable_id)
      return unless trackable

      attrs = attributes.symbolize_keys
      attrs[:occurred_at] = Time.parse(attrs[:occurred_at]) if attrs[:occurred_at].is_a?(String)

      # Log geo data status for debugging
      if attrs[:country_code].present?
        Rails.logger.debug { "[Footprinted] TrackJob received pre-extracted geo: #{attrs[:country_code]}/#{attrs[:city]}" }
      else
        Rails.logger.debug { "[Footprinted] TrackJob has no pre-extracted geo, will attempt lookup for #{attrs[:ip]}" }
      end

      trackable.footprints.create!(attrs)
    end
  end
end
