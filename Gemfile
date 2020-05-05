# frozen_string_literal: true

source 'https://rubygems.org'

ruby '2.7.1'

gem 'rails', '~> 6.0.2'
gem 'pg', '~> 1.2'
gem 'puma'

gem 'bootsnap', '>= 1.4.2', require: false
gem 'cancancan'
gem 'connection_pool'
gem 'devise-argon2'
gem 'devise_token_auth'
gem 'hiredis'
gem 'pry-rails'
gem 'rack-cors'
gem 'redis'
gem 'rswag-api'
gem 'rswag-ui'
gem 'sidekiq'

group :development, :test do
  gem 'brakeman', require: false
  gem 'dotenv-rails'
  gem 'fasterer', require: false
  gem 'overcommit', require: false
  gem 'pry-byebug'
  gem 'rails_best_practices', require: false
  gem 'rspec-rails'
  gem 'rswag-specs'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
end

group :development do
  gem 'bullet'
end

group :test do
  gem 'factory_bot_rails'
  gem 'shoulda-matchers'
end
