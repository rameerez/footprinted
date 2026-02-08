# frozen_string_literal: true

module Footprinted
  class Footprint < ActiveRecord::Base
    self.table_name = "footprints"

    belongs_to :trackable, polymorphic: true
    belongs_to :performer, polymorphic: true, optional: true

    validates :ip, presence: true
    validates :event_type, presence: true
    validates :occurred_at, presence: true

    before_validation :set_occurred_at
    before_save :set_geolocation_data

    scope :by_event,     ->(type) { where(event_type: type) }
    scope :by_country,   ->(code) { where(country_code: code) }
    scope :recent,       -> { order(occurred_at: :desc) }
    scope :between,      ->(start_date, end_date) { where(occurred_at: start_date..end_date) }
    scope :last_days,    ->(days) { where("occurred_at >= ?", days.days.ago) }
    scope :performed_by, ->(performer) { where(performer: performer) }

    def self.event_types
      distinct.pluck(:event_type)
    end

    def self.countries
      where.not(country_code: nil).distinct.pluck(:country_code)
    end

    private

    def set_occurred_at
      self.occurred_at ||= Time.current
    end

    def set_geolocation_data
      return if country_code.present?
      return unless ip.present?

      location = Trackdown.locate(ip.to_s, request: @_request)
      self.country_code  = location.country_code
      self.country_name  = location.country_name
      self.city          = location.city
      self.region        = location.region
      self.continent     = location.continent
      self.timezone      = location.timezone
      self.latitude      = location.latitude
      self.longitude     = location.longitude
    rescue => e
      Rails.logger.error "[Footprinted] Geolocation failed for #{ip}: #{e.message}"
    end
  end
end
