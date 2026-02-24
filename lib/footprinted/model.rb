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
            Footprinted::Model.enrich_with_geo_data!(attrs, ip, request)
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
        Footprinted::Model.enrich_with_geo_data!(attrs, ip, request)
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

    # Extract geo data from request (Cloudflare headers) before enqueueing
    # This allows async jobs to have geo data without needing MaxMind
    def self.enrich_with_geo_data!(attrs, ip, request)
      return unless request && defined?(Trackdown)

      location = Trackdown.locate(ip.to_s, request: request)
      attrs.merge!(
        country_code: location.country_code,
        country_name: location.country_name,
        city: location.city,
        region: location.region,
        continent: location.continent,
        timezone: location.timezone,
        latitude: location.latitude,
        longitude: location.longitude
      )

      if location.country_code.present?
        Rails.logger.debug { "[Footprinted] Extracted geo at enqueue: #{location.country_code}/#{location.city} for #{ip}" }
      end
    rescue => e
      # Geo-lookup failed (e.g., private IP, network error), but we still want to create the footprint
      Rails.logger.debug { "[Footprinted] Geo enrichment skipped (#{e.class}): #{e.message}" }
    end
  end
end
