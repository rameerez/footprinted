# 👣 `footprinted` - Simple event tracking for Rails apps

[![Gem Version](https://badge.fury.io/rb/footprinted.svg)](https://badge.fury.io/rb/footprinted) [![Build Status](https://github.com/rameerez/footprinted/workflows/Tests/badge.svg)](https://github.com/rameerez/footprinted/actions)

> [!TIP]
> **🚀 Ship your next Rails app 10x faster!** I've built **[RailsFast](https://railsfast.com/?ref=footprinted)**, a production-ready Rails boilerplate template that comes with everything you need to launch a software business in days, not weeks. Go [check it out](https://railsfast.com/?ref=footprinted)!

`footprinted` makes it trivial to add event tracking to any Rails model.

Think of a file transfer app like WeTransfer. You may want to track where every file download came from:

```ruby
# Add to your model
has_trackable :downloads

# Track events in the controller
@file.track_download(ip: request.remote_ip, metadata: { version: "2.1.0" })

# Query the data
@file.downloads.by_country("US").last_days(30).count
# => 42
```

In the example above, `footprinted` adds `footprints` to your `File` model, allowing you to easily record event data; and provides you with methods to build dashboards and analytics / business intelligence systems.

More use cases:
- Track login attempts
- Track profile views in a social app (think: LinkedIn)
- Track document open events in a file-signing app (think: DocuSign)
- Track any business-critical operation for enterprise-compliant audit logs
- Track any interaction where knowing the *where* (IP, geolocation) or *what* (OS, app version, device ID...) matters

Every event (footprint) in `footprinted` records the IP address, full geolocation data (country, city, region, coordinates, timezone), arbitrary JSONB metadata, and who triggered it — all resolved automatically via [`trackdown`](https://github.com/rameerez/trackdown). `footprinted` allows you to trivially build analytics dashboards and audit logs for all your app events.

> [!NOTE]
> By adding `has_trackable :downloads` to your model, `footprinted` automatically creates a `downloads` scoped association and a `track_download` method. No extra models or associations to define. Just track and query.

## Installation

Add this to your Gemfile:

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

> [!IMPORTANT]
> This gem depends on [`trackdown`](https://github.com/rameerez/trackdown) for IP geolocation. `trackdown` works out of the box with Cloudflare (zero config) and also supports MaxMind. See the [trackdown README](https://github.com/rameerez/trackdown) for setup instructions.

## Quick Start

Include the concern in any model you want to track activity on:

```ruby
class Product < ApplicationRecord
  include Footprinted::Model

  has_trackable :activations
  has_trackable :downloads
end
```

Track events in your controller:

```ruby
class DownloadsController < ApplicationController
  def create
    @product = Product.find(params[:product_id])
    @product.track_download(ip: request.remote_ip, metadata: { version: params[:version] })
  end
end
```

Query the data:

```ruby
@product.downloads.count                    # => 847
@product.downloads.by_country("US").count   # => 529
@product.downloads.last_days(7)             # recent downloads
@product.downloads.countries                # => ["US", "UK", "CA", ...]
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

Scopes are chainable:

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
@product.track(:activation, ip: request.remote_ip, metadata: {
  device_id: "A1B2C3",
  app_version: "2.1.0",
  platform: "macOS",
  os_version: "15.2",
  sdk_version: "0.4.0",
  locale: "en_US"
})
```

Query metadata using your database's JSON operators:

```ruby
# Find activations from macOS
@product.footprints
  .by_event("activation")
  .where("metadata->>'platform' = ?", "macOS")

# Group by app version
@product.footprints
  .by_event("activation")
  .group("metadata->>'app_version'")
  .count
# => { "2.0.0" => 12, "2.1.0" => 45 }
```

### Performance at scale

The default migration creates a [GIN index](https://www.postgresql.org/docs/current/gin-intro.html) on the `metadata` column. GIN indexes are excellent for **containment queries** (`@>`, `?`, `?|`) but do **not** speed up key extraction queries like `GROUP BY metadata->>'field'` or `COUNT(DISTINCT metadata->>'field')`.

For small-to-medium tables (up to hundreds of thousands of rows), JSONB queries work just fine. At larger scale (millions of rows), if you're frequently grouping or counting distinct values on specific metadata keys, you have two options:

**Option 1: Expression indexes** — add B-tree indexes on the specific JSONB keys you query most. No schema change needed:

```ruby
# In a migration in your host app
add_index :footprints, "(metadata->>'device_id')", name: "idx_footprints_device_id"
add_index :footprints, "(metadata->>'app_version')", name: "idx_footprints_app_version"
```

**Option 2: Promote to columns** — for your hottest query paths (e.g., `device_id` for DAU/MAU), add dedicated columns to the `footprints` table in your host app. This gives you proper B-tree indexes and fast `DISTINCT` counts:

```ruby
# In a migration in your host app
add_column :footprints, :device_id,    :string
add_column :footprints, :app_version,  :string
add_column :footprints, :platform,     :string

add_index :footprints, :device_id
add_index :footprints, :app_version
```

Your tracking calls stay the same — just pass everything in `metadata` as before. To auto-promote metadata keys into their dedicated columns, add a `before_save` callback in an initializer:

```ruby
# config/initializers/footprinted_extensions.rb

# String columns that map 1:1 from metadata
FOOTPRINT_PROMOTED_STRING_COLUMNS = %w[device_id app_version platform].freeze

# Integer columns that need casting
FOOTPRINT_PROMOTED_INTEGER_COLUMNS = %w[cpu_cores memory_gb].freeze

Rails.configuration.to_prepare do
  Footprinted::Footprint.class_eval do
    before_save :promote_metadata_columns

    private

    def promote_metadata_columns
      return if metadata.blank?

      m = metadata.stringify_keys

      FOOTPRINT_PROMOTED_STRING_COLUMNS.each do |key|
        self[key] = m[key] if self[key].blank? && m[key].present?
      end

      FOOTPRINT_PROMOTED_INTEGER_COLUMNS.each do |key|
        self[key] = m[key].to_i if self[key].blank? && m[key].present?
      end
    end
  end
end
```

This works regardless of how footprints are created — via `TrackJob` (async), direct `.create!`, or the Rails console. The gem stays generic; your app adds the columns and promotion logic it needs.

> [!TIP]
> Which metadata keys to promote depends on your use case. A licensing SaaS might promote `device_id` + `app_version`. An e-commerce app might promote `product_id` + `session_id`. A CMS might promote `page_url` + `referrer`. Keep the JSONB for everything else.

### Database compatibility

| Feature | PostgreSQL | MySQL 5.7+ | SQLite |
|---|---|---|---|
| JSONB `metadata` column | `jsonb` (native, fast) | `json` (native) | `text` (stored as string) |
| GIN index on `metadata` | Supported | Not supported | Not supported |
| JSON queries (`->>`, `@>`) | Full support | `JSON_EXTRACT()` syntax | `json_extract()` via extension |
| Expression indexes | Supported | Supported (generated columns) | Not supported |

PostgreSQL is the recommended database for `footprinted`. It has the best JSONB support, GIN indexes for containment queries, and expression indexes for key extraction. MySQL works but uses different JSON syntax. SQLite works for development and testing but stores metadata as text and has limited JSON query support.

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

If geolocation fails (network error, invalid IP, etc.), the footprint is still saved — just without geolocation data. Errors are logged via `Rails.logger`.

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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

### Releasing a new version

When bumping the version, update all three of these together:

1. `lib/footprinted/version.rb` — the version constant
2. `gemfiles/*.gemfile.lock` — run `bundle exec appraisal install` to regenerate
3. `test/footprinted/version_test.rb` — the hardcoded version assertion

CI will fail if any of these are out of sync.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rameerez/footprinted. Our code of conduct is: just be nice and make your mom proud of what you do and post online.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
