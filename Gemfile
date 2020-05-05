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
  gem 'dotenv-rails'
  gem 'factory_bot_rails'
  gem 'pry-byebug'
  gem 'rspec-rails'
  gem 'rswag-specs'
end

group :development do
  gem 'bullet'
  gem 'overcommit', require: false
end

group :test do
  gem 'shoulda-matchers'
end
