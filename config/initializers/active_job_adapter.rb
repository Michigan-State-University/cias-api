# frozen_string_literal: true

Sidekiq.configure_server do |config|
  if ENV['HEROKU_REDIS'] == 'true'
    config.redis = { url: ENV['REDIS_URL'], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
  else
    config.redis = { url: ENV['REDIS_URL'] }
  end
end

Sidekiq.configure_client do |config|
  if ENV['HEROKU_REDIS'] == 'true'
    config.redis = { url: ENV['REDIS_URL'], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
  else
    config.redis = { url: ENV['REDIS_URL'] }
  end
end
