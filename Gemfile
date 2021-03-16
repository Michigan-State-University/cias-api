# frozen_string_literal: true

source 'https://rubygems.org'

ruby '2.7.2'

gem 'rails', '~> 6.0'
gem 'pg', '~> 1.2'
gem 'puma', '~> 5.0'

gem 'activejob-cancel'
gem 'activerecord_json_validator'
gem 'active_storage_validations'
gem 'bootsnap', '>= 1.4', require: false
gem 'cancancan'
gem 'config'
gem 'connection_pool'
gem 'dentaku'
gem 'devise-argon2'
gem 'devise_invitable'
gem 'devise_token_auth'
gem 'faker', require: false
gem 'fast_jsonapi'
gem 'google-cloud-text_to_speech'
gem 'hiredis'
gem 'oj'
gem 'pagy'
gem 'phonelib'
gem 'postgresql_cursor'
gem 'pry-rails'
gem 'rack-cors'
gem 'redis'
gem 'sentry-raven'
gem 'sidekiq'
gem 'sql_query'
gem 'twilio-ruby', '~> 5.45.0'
gem 'wicked_pdf'
gem 'rack-attack'

group :development, :test do
  gem 'bundler-audit'
  gem 'brakeman', require: false
  gem 'bullet'
  gem 'dotenv-rails'
  gem 'fasterer', require: false
  gem 'overcommit', require: false
  gem 'pry-byebug'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-thread_safety', require: false
end

group :development do
  gem 'bump'
  gem 'guard-rake', require: false
  gem 'guard-rspec', require: false
  gem 'letter_opener_web'
  gem 'license_finder'
  gem 'pgsync'
  gem 'wkhtmltopdf-binary'
end

group :test do
  gem 'factory_bot_rails'
  gem 'rspec-rails'
  gem 'rspec-sidekiq'
  gem 'shoulda-matchers'
  gem 'simplecov', require: false
  gem 'test-prof'
  gem 'timecop'
end

group :production do
  gem 'aws-sdk-s3'
  gem 'wkhtmltopdf-heroku'
end
