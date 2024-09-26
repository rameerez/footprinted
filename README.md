# 👣 `footprinted` - Ruby gem to track IP-geolocated user activity

`footprinted` is a Ruby gem that provides a simple and elegant way to track user activity with associated IP addresses.

Think user profiles – `footprinted` allows you to add `has_trackable :views` in your User model, so you can trigger `@profile.track_view(request.remote_ip)` in your controller – to later compile stats on from where the profile has been visited.

It seamlessly integrates with your existing Rails models, allowing you to add trackable actions with minimal setup.

## Features

- 🔍 Easy-to-use model concern for tracking activities
- 🌍 IP geolocation using the [`trackdown`](https://github.com/rameerez/trackdown) gem
- 🚀 Customizable tracking associations
- 🛠 Generator for easy setup and migration
- 📊 Simple API for recording and querying tracked activities

## Installation

This gem depends on the [`trackdown`](https://github.com/rameerez/trackdown) gem for locating IPs. First, install `trackdown` and make sure you have a valid installation with a working MaxMind database, so we can get geolocation data from the IPs.

Then, add this line to your application's Gemfile:

```ruby
gem 'footprinted'
```

And then execute:

```bash
bundle install
```

## Setup

Run the installation generator:

```bash
rails generate footprinted:install
```

This will create:
- An initializer file at `config/initializers/footprinted.rb`
- A migration file to create the polymorphic `trackable_activities` table

Finally, run the migration:

```bash
rails db:migrate
```

## Usage

### Basic Usage

Include the `Footprinted::Model` concern in your model and set what kind of activity you're tracking:
```ruby
class User < ApplicationRecord
  include Footprinted::Model
  has_trackable :profile_views
end
```

The `has_trackable :profile_views` association automatically provides you with a `track_profile_view` method you can use:
```ruby
user = user.find(1)
user.track_profile_view(ip: '8.8.8.8')
```

You can query profile views with:
```ruby
user.profile_views
```

For example, you can get the total count of visits per country easily:
```ruby
user.profile_views.group(:country).count
# => { 'US'=>529, 'UK'=>291, 'CA'=>78... }
```

If you want to also save which user triggered the activity, you can do so with:
```ruby
user.track_profile_view(ip: '8.8.8.8', user: @user)
```

## Configuration

You can configure Footprinted in the `config/initializers/footprinted.rb` file:

```ruby
Footprinted.configure do |config|
  config.ip_lookup_service = :trackdown # Default
  # Add any other configuration options here
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rameerez/trackdown. Our code of conduct is: just be nice and make your mom proud of what you do and post online.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
