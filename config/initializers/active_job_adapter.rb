# frozen_string_literal: true

pool = ConnectionPool.new(size: ENV.fetch('REDIS_CONNECTIONS_POOL', 12)) do
  Redis.new(url: ENV['REDIS_URL'], driver: :ruby, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
end

Sidekiq.configure_server do |config|
  config.redis = pool
end

Sidekiq.configure_client do |config|
  config.redis = pool
end
