# frozen_string_literal: true

module Footprinted
  class TrackableActivity < ActiveRecord::Base
    # Associations
    belongs_to :trackable, polymorphic: true
    belongs_to :performer, polymorphic: true, optional: true

    # Validations
    validates :ip, presence: true
    validates :activity_type, presence: true
    validates :trackable, presence: true

    # Callbacks
    before_save :set_geolocation_data

    # Scopes
    scope :by_activity, ->(type) { where(activity_type: type) }
    scope :by_country, ->(country) { where(country: country) }
    scope :recent, -> { order(created_at: :desc) }
    scope :performed_by, ->(performer) { where(performer: performer) }
    scope :between, ->(start_date, end_date) { where(created_at: start_date..end_date) }
    scope :last_days, ->(days) { where('created_at >= ?', days.days.ago) }

    # Class methods
    def self.activity_types
      distinct.pluck(:activity_type)
    end

    def self.countries
      distinct.where.not(country: nil).pluck(:country)
    end
    private

    def set_geolocation_data
      return unless ip.present?

      unless defined?(Trackdown)
        raise Footprinted::Error, "Trackdown gem is not installed. Please add `gem 'trackdown'` to your Gemfile."
      end

      unless Trackdown.database_exists?
        raise Footprinted::Error, "Trackdown database not found. Please follow the Trackdown gem setup instructions to configure the gem and download an IP geolocation database."
      end

      location = Trackdown.locate(ip.to_s)
      self.country = location.country_code
      self.city = location.city
    rescue => e
      Rails.logger.error "Failed to geolocate IP #{ip}: #{e.message}"
      nil # Don't fail the save if geolocation fails
    end
  end
end
