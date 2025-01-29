# frozen_string_literal: true

module Rack
end

class Rack::HealthCheck
  # It return system details in JSON response.
  #
  # @return [Array] which is compatible with Rack format.
  #
  # @example Check system details:
  #   Rack::HealthCheck.new.call({})  #=> [200, {}, ["{\"database\":true}"]]
  def call(_env)
    status = { database: postgresql, redis: redis }

    [200, {}, [status.to_json]]
  end

  private

  # It checks status of the PostgreSQL database.
  #
  # @return [Boolean] which describes PostgreSQL instance status.
  def postgresql
    ActiveRecord::Base.connection.execute 'SELECT 1'
    ApplicationRecord.connected?
  rescue StandardError
    false
  end

  def redis
    Sidekiq.redis(&:ping)
    true
  rescue StandardError
    false
  end
end
