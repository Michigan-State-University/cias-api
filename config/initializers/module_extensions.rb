# frozen_string_literal: true

require 'action_cable/engine'
require 'action_cable/subscription_adapter/redis'

ActionCable::SubscriptionAdapter::Redis.include(RedisAdapterOverrides)
