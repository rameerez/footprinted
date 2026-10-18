# frozen_string_literal: true

appraise "rails-7.2" do
  gem "rails", "~> 7.2.0"
  # Rails < 7.2.4 passes quirks_mode: to JSON.generate; json >= 3 rejects unknown keywords.
  gem "json", "~> 2.7"
end

appraise "rails-8.1" do
  gem "rails", "~> 8.1.2"
end
