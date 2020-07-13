# frozen_string_literal: true

source 'https://rubygems.org'

ruby '2.7.1'

gem 'rails', '~> 6.0'
gem 'pg', '~> 1.2'
gem 'puma'

gem 'activerecord_json_validator'
gem 'bootsnap', '>= 1.4', require: false
gem 'cancancan'
gem 'connection_pool'
gem 'dentaku'
gem 'devise-argon2'
gem 'devise-pwned_password'
gem 'devise_token_auth'
gem 'fast_jsonapi'
gem 'hiredis'
gem 'oj'
gem 'postgresql_cursor'
gem 'pry-rails'
gem 'rack-cors'
gem 'redis'
gem 'sidekiq'
gem 'sql_query'

group :development, :test do
  gem 'brakeman', require: false
  gem 'bullet'
  gem 'dotenv-rails'
  gem 'faker'
  gem 'fasterer', require: false
  gem 'overcommit', require: false
  gem 'pry-byebug'
  gem 'rails_best_practices', require: false
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-thread_safety', require: false
end

group :development do
  gem 'guard-rake', require: false
  gem 'guard-rspec', require: false
  gem 'letter_opener'
end

group :test do
  gem 'factory_bot_rails'
  gem 'rspec-rails'
  gem 'rspec-sidekiq'
  gem 'shoulda-matchers'
end
