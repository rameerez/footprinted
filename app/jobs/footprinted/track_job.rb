# frozen_string_literal: true

module Footprinted
  class TrackJob < ActiveJob::Base
    queue_as :default

    def perform(trackable_type, trackable_id, attributes)
      trackable = trackable_type.constantize.find_by(id: trackable_id)
      return unless trackable

      attrs = attributes.symbolize_keys
      attrs[:occurred_at] = Time.parse(attrs[:occurred_at]) if attrs[:occurred_at].is_a?(String)

      trackable.footprints.create!(attrs)
    end
  end
end
