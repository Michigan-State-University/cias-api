# frozen_string_literal: true

module RedisAdapterOverrides
  extend ActiveSupport::Concern

  # rubocop:disable ThreadSafety/ClassAndModuleAttributes
  included do
    cattr_accessor :redis_connector, default: lambda { |config|
      ::Redis.new({ driver: :ruby, **config.except(:adapter, :channel_prefix, :ssl_params), ssl_params: config[:ssl_params] })
    }
  end
  # rubocop:enable ThreadSafety/ClassAndModuleAttributes
end
