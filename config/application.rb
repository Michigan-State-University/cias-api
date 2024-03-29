# frozen_string_literal: true

require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
# require "action_mailbox/engine"
# require "action_text/engine"
require 'action_view/railtie'
require 'action_cable/engine'
# require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.

Bundler.require(*Rails.groups)

module CiasApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.i18n.tap do |i18n|
      i18n.available_locales = %i[en ar es]
      i18n.default_locale = :en
      i18n.enforce_available_locales = false
      i18n.fallbacks = true
    end

    config.active_job.queue_adapter = :sidekiq
    config.filter_parameters << :password_confirmation
    config.middleware.insert_before(Rack::Sendfile, Rack::Deflater)
    routes.default_url_options = { host: ENV['APP_HOSTNAME'] }
    config.eager_load_paths += %W[#{config.root}/lib/rack]
    config.middleware.use ActionDispatch::Flash
    config.filter_parameters << %i[password password_confirmation email first_name last_name]
  end
end
