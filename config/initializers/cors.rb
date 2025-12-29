# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    allowed_origins = [ENV.fetch('WEB_URL', nil)].compact
    additional_origins = ENV.fetch('ADDITIONAL_CORS_ORIGINS', '').split(',').map(&:strip).reject(&:empty?)
    allowed_origins.concat(additional_origins)

    origins allowed_origins
    resource '*',
             headers: :any,
             credentials: true,
             expose: %w[Access-Token Expiry Token-Type Uid Client],
             methods: %i[delete get options patch post put]
  end
end
