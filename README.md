# 👣 `footprinted` - Ruby gem to track geolocated user activity

`footprinted` is a Ruby gem that provides a simple and elegant way to track user activity with associated IP addresses and geo data.

Example: think user profiles – this gem allows you to add
```ruby
has_trackable :profile_views
```

to your User model, so you can call:
```ruby
@profile.track_profile_view(request.remote_ip)
```

in your controller and track profile views with geolocation.

You can then easily compile stats on from where the profile has been visited, like:
```ruby
user.profile_views.group(:country).count
# => { 'US'=>529, 'UK'=>291, 'CA'=>78... }
```

`footprinted` seamlessly integrates with your existing Rails models, allowing you to add multiple trackable actions with minimal setup.

## Installation

> [!IMPORTANT]
> This gem depends on the [`trackdown`](https://github.com/rameerez/trackdown) gem for locating IPs.
>
> **Start by following the `trackdown` README to install and configure the gem**, and make sure you have a valid installation with a working MaxMind database before continuing – otherwise we won't be able to get any geolocation data from IPs.

After [`trackdown`](https://github.com/rameerez/trackdown) is installed and configured, add this line to your application's Gemfile:

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

Include the `Footprinted::Model` concern in your model and set what kind of activity you're tracking:
```ruby
class User < ApplicationRecord
  include Footprinted::Model
  has_trackable :profile_views
end
```

The `has_trackable :profile_views` association automatically provides you with a `track_profile_view` method that you can use:
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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rameerez/footprinted. Our code of conduct is: just be nice and make your mom proud of what you do and post online.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
