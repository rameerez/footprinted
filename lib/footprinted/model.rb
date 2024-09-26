# frozen_string_literal: true

module Footprinted
  module Model
    extend ActiveSupport::Concern

    # The Footprinted::Model module provides a flexible way to track activities related to any model that includes this concern.
    #
    # Footprinted tracks activities through a polymorphic association: the Footprinted::TrackableActivity model.
    #
    # The Footprinted::Model concern sets up a :trackable_activities association using the
    # Footprinted::TrackableActivity model.
    #
    # It also provides a basic method to track unnamed activities, `track_activity`,
    # which can be used as is (not recommended) or overridden with a custom activity type:
    #
    # Track specific types of activities using the `has_trackable` class method.
    # This method also dynamically defines a method to create activity records for the custom association.
    # For example, `has_trackable :profile_views` generates the `track_profile_view` method.
    #
    # Example:
    #   class YourModel < ApplicationRecord
    #     include Trackable
    #     has_trackable :profile_views
    #   end
    #
    # The above will:
    # - Create a `has_many :profile_views` association.
    # - Define a method `track_profile_view` (singular) to create records in `profile_views`.
    #
    #
    # Methods:
    #
    # - has_trackable(association_name): Sets up a custom association for tracking activities.
    #   This method dynamically defines a tracking method based on the given association name.
    #
    # - track_activity(ip, user = nil): Default method provided to track activities. It logs
    #   the IP address, and optionally, the user involved in the activity. This method can be
    #   overridden in the model including this module for custom behavior.
    #
    # Note:
    # The Footprinted::TrackableActivity model must exist and have a polymorphic association set up
    # with the :trackable attribute for this concern to function correctly.

    included do
      has_many :trackable_activities, as: :trackable, class_name: 'Footprinted::TrackableActivity', dependent: :destroy
    end

    class_methods do
      # Method to set custom association names
      def has_trackable(association_name)
        track_method_name = "track_#{association_name.to_s.singularize}"

        has_many association_name, -> { where(activity_type: association_name.to_s.singularize) },
                 as: :trackable, class_name: 'Footprinted::TrackableActivity'

        # Define a custom method for tracking activities of this type
        define_method(track_method_name) do |ip:, user: nil|
          send(association_name).create(ip: ip, user: user, activity_type: association_name.to_s.singularize)
        end
      end
    end

    # Fallback method for tracking activity. This will be overridden if has_trackable is called.
    def track_activity(ip:, user: nil, activity_type: nil)
      trackable_activities.create(ip: ip, user: user, activity_type: activity_type)
    end
  end
end
