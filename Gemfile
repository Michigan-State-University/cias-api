# frozen_string_literal: true

source 'https://rubygems.org'

ruby '2.7.2'

gem 'rails', '~> 6.1.6'
gem 'pg', '~> 1.2'
gem 'puma', '>= 5.6.4'

gem 'activejob-cancel'
gem 'activerecord_json_validator'
gem 'activestorage', '>= 6.1.4.7'
gem 'active_storage_validations'
gem 'active_model_serializers', '~> 0.10.0'
gem 'bootsnap', '>= 1.4', require: false
gem 'cancancan'
gem 'config'
gem 'connection_pool'
gem 'dentaku'
gem 'devise-argon2'
gem 'devise_invitable'
gem 'devise_token_auth'
gem 'faker', require: false
gem 'jsonapi-serializer'
gem 'jmespath', '>= 1.6.1'
gem 'google-cloud-text_to_speech'
gem 'google-cloud-translate-v2'
gem 'google-protobuf', '~> 3.19.6'
gem 'hiredis'
gem 'metainspector', '~> 1.15'
gem 'nokogiri', '>= 1.13.9'
gem 'oj'
gem 'pagy'
gem 'phonelib'
gem 'postgresql_cursor'
gem 'pry-rails'
gem 'rack-cors'
gem 'redis'
gem 'sidekiq', '>= 6.4.0'
gem 'sql_query'
gem 'twilio-ruby', '~> 5.45.0'
gem 'wicked_pdf'
gem 'rack', '>= 2.2.3.1'
gem 'rack-attack'
gem 'rails-html-sanitizer', '>= 1.4.3'
gem 'secure_headers'
gem 'airbrake'
# for encrypt data
gem 'lockbox'
# for search on encrypted data
gem 'blind_index'
# for stop logging sensitive data
gem 'logstop'
gem 'countries'
# for Audit trail and audit log
gem 'paper_trail'
# for soft delete
gem 'paranoia', '~> 2.4', '>= 2.4.3'
# for logging errors
gem 'sentry-ruby'
gem 'sentry-rails'

group :development, :test do
  gem 'bundler-audit'
  gem 'brakeman', '~> 5.0.2', require: false
  gem 'bullet'
  gem 'dotenv-rails'
  gem 'fasterer', require: false
  gem 'overcommit', require: false
  gem 'pry-byebug'
  gem 'rack-test'
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
end

group :test do
  gem 'factory_bot_rails'
  gem 'rspec-rails'
  gem 'shoulda-matchers'
  gem 'simplecov', require: false
  gem 'test-prof'
  gem 'timecop'
  gem 'database_cleaner-active_record'
  gem 'action-cable-testing', '~> 0.6.1'
  gem 'rspec-benchmark'
  gem 'benchmark-ips'
end

group :production do
  gem 'aws-sdk-s3'
end

group :development, :production do
  # only version that is working on AWS
  gem 'wkhtmltopdf-heroku', '2.12.6.0'
end
