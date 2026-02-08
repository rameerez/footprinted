# 👣 `footprinted` - Track geolocated user activity in your Rails app

[![Gem Version](https://badge.fury.io/rb/footprinted.svg)](https://badge.fury.io/rb/footprinted) [![Build Status](https://github.com/rameerez/footprinted/workflows/Tests/badge.svg)](https://github.com/rameerez/footprinted/actions)

> [!TIP]
> **🚀 Ship your next Rails app 10x faster!** I've built **[RailsFast](https://railsfast.com/?ref=footprinted)**, a production-ready Rails boilerplate template that comes with everything you need to launch a software business in days, not weeks. Go [check it out](https://railsfast.com/?ref=footprinted)!

`footprinted` makes it trivial to track user activity with associated IP addresses, geolocation data, and arbitrary metadata in your Rails app. It's great for tracking profile views, downloads, login attempts, license activations, or any user interaction where knowing the location matters.

```ruby
# Add to your model
has_trackable :profile_views

# Track activity in the controller
@user.track_profile_view(ip: request.remote_ip)

# Query the data
@user.profile_views.by_country("US").last_days(30).count
# => 42
```

That's it! `footprinted` stores the activity along with the IP's full geolocation data, all automatically resolved via [Trackdown](https://github.com/rameerez/trackdown).

> [!NOTE]
> By adding `has_trackable :profile_views` to your model, `footprinted` automatically creates a `profile_views` scoped association and a `track_profile_view` method. No extra models or associations to define. Just track and query.

## Installation

> [!IMPORTANT]
> This gem depends on [`trackdown`](https://github.com/rameerez/trackdown) for IP geolocation. **Install and configure `trackdown` first** (follow its README), making sure you have a working MaxMind database before continuing.

After `trackdown` is set up, add this to your Gemfile:

```ruby
gem "footprinted"
```

Then run:

```bash
bundle install
rails generate footprinted:install
rails db:migrate
```

This creates the `footprints` table with columns for IP, geolocation fields, event type, JSONB metadata, polymorphic trackable/performer references, and all the necessary indexes.

## Quick Start

Include the concern in any model you want to track activity on:

```ruby
class User < ApplicationRecord
  include Footprinted::Model

  has_trackable :profile_views
end
```

Track activity in your controller:

```ruby
class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @user.track_profile_view(ip: request.remote_ip)
  end
end
```

Query the data:

```ruby
@user.profile_views.count                    # => 847
@user.profile_views.by_country("US").count   # => 529
@user.profile_views.last_days(7)             # recent views
@user.profile_views.countries                # => ["US", "UK", "CA", ...]
```

## `has_trackable` DSL

Declare one or more trackable event types on any model:

```ruby
class Resource < ApplicationRecord
  include Footprinted::Model

  has_trackable :downloads
  has_trackable :previews
  has_trackable :shares
end
```

Each `has_trackable` call gives you:

- A **scoped association** (e.g., `resource.downloads`) that only returns footprints of that event type
- A **track method** (e.g., `resource.track_download(ip:)`) that creates footprints with the correct event type

The association name is pluralized, and the track method is singularized:

| Declaration | Association | Track method |
|---|---|---|
| `has_trackable :profile_views` | `.profile_views` | `.track_profile_view(ip:)` |
| `has_trackable :downloads` | `.downloads` | `.track_download(ip:)` |
| `has_trackable :login_attempts` | `.login_attempts` | `.track_login_attempt(ip:)` |

### Track method parameters

```ruby
@resource.track_download(
  ip: request.remote_ip,          # Required: the IP address
  request: request,               # Optional: passed to Trackdown for better geolocation
  performer: current_user,        # Optional: who triggered this activity
  metadata: { browser: "Chrome" },# Optional: arbitrary JSONB metadata
  occurred_at: 2.hours.ago        # Optional: defaults to Time.current
)
```

## Generic `track()` method

For ad-hoc event types that don't need a dedicated association, use the generic `track` method:

```ruby
@user.track(:signup, ip: request.remote_ip)
@user.track(:password_reset, ip: request.remote_ip, performer: admin)
@user.track("api_call", ip: request.remote_ip, metadata: { endpoint: "/users" })
```

It accepts the same parameters as `track_<event_type>` and works with both symbols and strings. All events tracked this way are accessible through the `footprints` association:

```ruby
@user.footprints.by_event("signup").count
```

## Scopes

`footprinted` provides several useful scopes out of the box:

```ruby
# Filter by event type
@user.footprints.by_event("download")

# Filter by country code
@user.footprints.by_country("US")

# Order by most recent
@user.footprints.recent

# Time-based filtering
@user.footprints.last_days(30)
@user.footprints.between(1.week.ago, Time.current)

# Filter by performer
@user.footprints.performed_by(some_user)
```

Scopes are chainable, so you can combine them:

```ruby
@user.profile_views
  .by_country("US")
  .last_days(7)
  .performed_by(current_user)
  .recent
```

### Class methods

```ruby
# Get all distinct event types
Footprinted::Footprint.event_types
# => ["view", "download", "login"]

# Get all distinct country codes (excludes nil)
Footprinted::Footprint.countries
# => ["US", "UK", "CA", "DE"]
```

## JSONB metadata

Every footprint can store arbitrary metadata as JSONB. This is great for device info, SDK versions, or any context you want to associate with the event:

```ruby
@license.track(:activation, ip: request.remote_ip, metadata: {
  sdk_version: "0.4.0",
  os_name: "macOS",
  os_version: "15.2",
  device_model: "Mac15,3",
  app_version: "2.1.0",
  locale: "en_US",
  timezone: "America/Los_Angeles"
})
```

You can query metadata using your database's JSON operators. For example, with PostgreSQL:

```ruby
# Find activations from macOS devices
@license.footprints
  .by_event("activation")
  .where("metadata->>'os_name' = ?", "macOS")

# Group by SDK version
@license.footprints
  .by_event("activation")
  .group("metadata->>'sdk_version'")
  .count
# => { "0.3.0" => 12, "0.4.0" => 45 }
```

## Async mode with ActiveJob

For high-traffic endpoints, you can enqueue footprint creation in the background:

```ruby
# config/initializers/footprinted.rb
Footprinted.configure do |config|
  config.async = true
end
```

When async is enabled, `track` and `track_<event_type>` calls enqueue a `Footprinted::TrackJob` instead of writing to the database immediately. The job serializes all attributes (including metadata as a hash and occurred_at as ISO 8601) and processes them in the background.

You need a working ActiveJob backend (Sidekiq, Solid Queue, etc.) for this to work.

## Geolocation via Trackdown

`footprinted` automatically resolves geolocation data from IP addresses using the [`trackdown`](https://github.com/rameerez/trackdown) gem. For every footprint, the following fields are populated:

| Field | Example |
|---|---|
| `country_code` | `"US"` |
| `country_name` | `"United States"` |
| `city` | `"San Francisco"` |
| `region` | `"California"` |
| `continent` | `"NA"` |
| `timezone` | `"America/Los_Angeles"` |
| `latitude` | `37.7749` |
| `longitude` | `-122.4194` |

If geolocation fails (network error, invalid IP, etc.), the footprint is still saved -- just without geolocation data. Errors are logged via `Rails.logger`.

If you already know the `country_code`, you can set it directly and geolocation will be skipped:

```ruby
@user.track_profile_view(ip: "1.2.3.4", country_code: "DE")
```

## Configuration

Create an initializer (the generator does this for you):

```ruby
# config/initializers/footprinted.rb
Footprinted.configure do |config|
  # Enqueue footprint creation via ActiveJob (default: false)
  config.async = false
end
```

## Generator

The install generator creates two things:

1. A migration for the `footprints` table with all geolocation columns, polymorphic references, JSONB metadata, indexes, and a composite index on `[trackable_type, trackable_id, event_type, occurred_at]`
2. An initializer at `config/initializers/footprinted.rb`

```bash
rails generate footprinted:install
rails db:migrate
```

## Testing

Run the test suite with:

```bash
bundle install
bundle exec rake test
```

The test suite uses SQLite3 in-memory database and requires no additional setup.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rameerez/footprinted. Our code of conduct is: just be nice and make your mom proud of what you do and post online.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
