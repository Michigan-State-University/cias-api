# frozen_string_literal: true

$redis = Redis.new( # rubocop:disable Style/GlobalVars
  url: ENV.fetch('REDIS_URL', nil),
  ssl_params: { verify_mode: ENV.fetch('REDIS_SSL_VERIFY', 'false') == 'true' ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE }
)
