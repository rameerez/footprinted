# 👣 `footprinted` - Track geolocated user activity in Rails

`footprinted` provides a simple way to track user activity with associated IP addresses and geolocation data in your Rails app.

It's good for tracking profile views, downloads, login attempts, or any user interaction where location matters.

## Why

Sometimes you need to know where your users are performing certain actions from.

For example, let's say your users have profiles. Where has a particular profile been viewed from?

This gem makes it trivial to track and analyze this kind of data:

```ruby
# First, add this to your User model
has_trackable :profile_views

# Then, track the activity in the controller
@user.track_profile_view(request.remote_ip)

# And finally, analyze the data
@user.profile_views.group(:country).count
# => { 'US'=>529, 'UK'=>291, 'CA'=>78... }
```

That's it! This is all you need for `footprinted` to store the profile view along with the IP's geolocation data.

> [!NOTE]
> By adding `has_trackable :profile_views` to your model, `footprinted` automatically creates a `profile_views` association and a `track_profile_view` method to your User model.
>
> `footprinted` does all the heavy lifting for you, so you don't need to define any models or associations. Just track and query.


## How it works

`footprinted` relies on a `trackable_activities` table, and provides a model concern to interact with it.

This model concern allows you to define polymorphic associations to store activity data associated with any model.

For each activity, `footprinted` stores:
- IP address
- Country
- City
- Activity type
- Event timestamp
- Optionally, an associated `performer` record, which could be a `user`, `admin`, or any other model. It answers the question: "who triggered this activity?"

`footprinted` also provides named methods that interact with the `trackable_activities` table to save and query this data.

For example, `has_trackable :profile_views` will generate the `profile_views` association and the `track_profile_view` method. Similarly, `has_trackable :downloads` will generate the `downloads` association and the `track_download` method.

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

Include the `Footprinted::Model` concern and declare what you want to track:

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

### Recording Activity

`footprinted` generates methods for you.

For example, the `has_trackable :profile_views` association automatically provides you with a `track_profile_view` method that you can use:

```ruby
# Basic tracking with IP
user.track_profile_view(ip: request.remote_ip)

# Or track with a performer as well ("who triggered the activity?")
user.track_profile_view(
  ip: request.remote_ip,
  performer: current_user
)
```

### Querying Activity

#### Basic Queries

```ruby
# Basic queries
user.profile_views.recent
user.profile_views.last_days(7)
user.profile_views.between(1.week.ago, Time.current)

# Location queries
user.profile_views.by_country('US')
user.profile_views.countries  # => ['US', 'UK', 'CA', ...]

# Performer queries
user.profile_views.performed_by(some_user)
```

### Advanced Usage

Track multiple activity types:

```ruby
class Resource < ApplicationRecord
  include Footprinted::Model
  
  has_trackable :downloads
  has_trackable :previews
end

# Track activities
product.track_download(ip: request.remote_ip)
product.track_preview(ip: request.remote_ip)

# Query activities
product.downloads.count
product.previews.last_days(30)
```

Time-based analysis:

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
