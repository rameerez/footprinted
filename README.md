# 👣 `footprinted` - Track geolocated user activity in Rails

`footprinted` provides a simple and elegant way to track user activity with associated IP addresses and geolocation data in your Rails app.

It's perfect for tracking profile views, downloads, login attempts, or any user interaction where location matters.

## Why

Sometimes you need to know where your users are performing certain actions from.

For example, let's assume users have profiles. Where has a particular profile been viewed from?

This gem makes it trivial to track and analyze this kind of data:

```ruby
# Get views by country
@user.profile_views.group(:country).count
# => { 'US'=>529, 'UK'=>291, 'CA'=>78... }

# Get recent profile views
@user.profile_views.last_days(7)

# Get views from a specific country
@user.profile_views.by_country('US')
```

`footprinted` does all the heavy lifting for you, so you don't need to define any models or associations.

## How

Continuing with the profile views example:

To track profile views in your User model, just add:

```ruby
has_trackable :profile_views
```

This will automatically add a `profile_views` association to your User model, and a `track_profile_view` method.

You can then track profile views like this:

```ruby
@user.track_profile_view(request.remote_ip)
```

This will store the event, along with the IP address and geolocation data associated with each profile view.

Then, as we've seen above, you can query the tracked activity with the `profile_views` association:

```ruby
user.profile_views.group(:country).count
# => { 'US'=>529, 'UK'=>291, 'CA'=>78... }
```

`footprinted` seamlessly integrates with your existing Rails models, allowing you to add multiple trackable actions with minimal setup.

## What

What `footprinted` provides is essentially a model mixin that defines a polymorphic association to store activity data associated with any model. Each of these activity datapoints includes an IP address and associated geolocation data.

This data gets stored in a table named `trackable_activities`.

For each activity, this gets stored:
- IP address
- Country
- City
- Activity type
- Event timestamp
- Optionally, an associated `performer` record, which could be a `user`, `admin`, or any other model. It answers the question: who triggered this activity?

For your convenience, `footprinted` provides named methods that interact with the `trackable_activities` table to save and query this data (like `track_profile_view` and `profile_views`). But it could also be queried and saved by directly interacting with the `trackable_activities` relationship.

## Installation

> [!IMPORTANT]
> This gem depends on the [`trackdown`](https://github.com/rameerez/trackdown) gem for locating IPs.
>
> **Start by following the `trackdown` README to install and configure the gem**, and make sure you have a valid installation with a working MaxMind database before continuing – otherwise we won't be able to get any geolocation data from IPs.

After [`trackdown`](https://github.com/rameerez/trackdown) has been installed and configured, add this line to your application's Gemfile:

```ruby
gem 'footprinted'
```

And then execute:

```bash
bundle install
rails generate footprinted:install
rails db:migrate
```

This will create a migration file to create the polymorphic `trackable_activities` table, and migrate the database.

## Usage

### Basic Setup

Include the concern and declare what you want to track:

```ruby
class User < ApplicationRecord
  include Footprinted::Model
  
  # Track a single activity type
  has_trackable :profile_views
  
  # Track multiple activity types
  has_trackable :downloads
  has_trackable :login_attempts
end
```

`footprinted` generates methods for you. For example, the `has_trackable :profile_views` association automatically provides you with a `track_profile_view` method that you can use:

```ruby
# Basic tracking with IP
user.track_profile_view(ip: request.remote_ip)

# Track with a performer (who triggered the activity)
user.track_profile_view(
  ip: request.remote_ip,
  performer: current_user
)
```

### Querying Activity

#### Basic Queries

```ruby
# Get all profile views
user.profile_views

# Get recent activity first
user.profile_views.recent

# Get activity from last X days
user.profile_views.last_days(7)

# Get activity between dates
user.profile_views.between(1.week.ago, Time.current)
```

#### Location-based Queries

```ruby
# Get activity from a specific country
user.profile_views.by_country('US')

# Get activity grouped by country
user.profile_views.group(:country).count
# => { 'US'=>529, 'UK'=>291, 'CA'=>78... }

# Get all countries with activity
user.profile_views.countries
# => ['US', 'UK', 'CA', ...]
```

#### Performer Queries

```ruby
# Get activity by a specific performer
user.profile_views.performed_by(some_user)

# Group by performer
user.profile_views
  .joins(:performer)
  .group('performers_trackable_activities.id')
  .count
```

### Advanced Usage

#### Working with Multiple Activity Types

```ruby
class Resource < ApplicationRecord
  include Footprinted::Model
  
  has_trackable :downloads
  has_trackable :previews
end

# Track different activities
resource.track_download(ip: request.remote_ip)
resource.track_preview(ip: request.remote_ip)

# Query specific activity types
resource.downloads.count
resource.previews.last_days(30)

# Get all activity types recorded
resource.trackable_activities.activity_types
# => ['download', 'preview']
```

#### Time-based Analysis

```ruby
# Daily activity for the last 30 days
resource.downloads
  .where('created_at > ?', 30.days.ago)
  .group("DATE(created_at)")
  .count
  .transform_keys { |k| k.strftime("%Y-%m-%d") }
# => {"2024-03-26" => 5, "2024-03-25" => 3, ...}

# Hourly distribution
resource.downloads
  .group("HOUR(created_at)")
  .count
# => {0=>10, 1=>5, 2=>8, ...}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rameerez/footprinted. Our code of conduct is: just be nice and make your mom proud of what you do and post online.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
