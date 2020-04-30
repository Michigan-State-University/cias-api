# frozen_string_literal: true

REDIS_CONNECTION_POOL = ConnectionPool.new(size: ENV.fetch('KEY_VALUE_DB_CONNECTIONS') { 10 } ) do
  Redis.new(url: ENV['KEY_VALUE_DB'])
end

Sidekiq.configure_server do |config|
  config.redis = REDIS_CONNECTION_POOL
end

Sidekiq.configure_client do |config|
  config.redis = REDIS_CONNECTION_POOL
end
