# frozen_string_literal: true

Sidekiq.configure_server do |config|
  if ENV['REDIS_PROVIDED_BY_HEROKU'] == 'true'
    config.redis = { url: ENV.fetch('REDIS_URL', nil), ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
  else
    config.redis = { url: ENV.fetch('REDIS_URL', nil) }
  end

  # Route through Rails.logger so Logstop scrubs PII from job-args on retry; keep dev unchanged.
  config.logger = Rails.logger unless Rails.env.development?
end

Sidekiq.configure_client do |config|
  if ENV['REDIS_PROVIDED_BY_HEROKU'] == 'true'
    config.redis = { url: ENV.fetch('REDIS_URL', nil), ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
  else
    config.redis = { url: ENV.fetch('REDIS_URL', nil) }
  end
end
