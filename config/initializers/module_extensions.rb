# frozen_string_literal: true

require 'action_cable/engine'
require 'action_cable/subscription_adapter/redis'
require_relative '../../app/channels/concerns/redis_adapter_overrides'

ActionCable::SubscriptionAdapter::Redis.include(RedisAdapterOverrides)
