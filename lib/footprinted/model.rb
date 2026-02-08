# frozen_string_literal: true

module Footprinted
  module Model
    extend ActiveSupport::Concern

    included do
      has_many :footprints, as: :trackable, class_name: "Footprinted::Footprint", dependent: :destroy
    end

    class_methods do
      def has_trackable(association_name)
        event_type = association_name.to_s.singularize
        track_method = "track_#{event_type}"

        has_many association_name,
          -> { where(event_type: event_type) },
          as: :trackable,
          class_name: "Footprinted::Footprint"

        define_method(track_method) do |ip:, request: nil, performer: nil, metadata: {}, occurred_at: nil|
          attrs = {
            ip: ip,
            performer: performer,
            event_type: event_type,
            metadata: metadata,
            occurred_at: occurred_at || Time.current
          }

          if Footprinted.configuration.async
            Footprinted::TrackJob.perform_later(
              self.class.name, id,
              attrs.merge(occurred_at: attrs[:occurred_at].iso8601)
            )
          else
            record = send(association_name).new(attrs)
            record.instance_variable_set(:@_request, request)
            record.save!
            record
          end
        end
      end
    end

    def track(event_type, ip:, request: nil, performer: nil, metadata: {}, occurred_at: nil)
      attrs = {
        ip: ip,
        performer: performer,
        event_type: event_type.to_s,
        metadata: metadata,
        occurred_at: occurred_at || Time.current
      }

      if Footprinted.configuration.async
        Footprinted::TrackJob.perform_later(
          self.class.name, id,
          attrs.merge(occurred_at: attrs[:occurred_at].iso8601)
        )
      else
        record = footprints.new(attrs)
        record.instance_variable_set(:@_request, request)
        record.save!
        record
      end
    end
  end
end
