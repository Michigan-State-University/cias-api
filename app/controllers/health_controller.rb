# frozen_string_literal: true

# Unauthenticated readiness endpoint for ALB / ECS health checks.
# Returns 503 when Postgres is unreachable, 200 otherwise. Redis is reported but
# doesn't fail the check: replacing every task wouldn't bring Redis back.
class HealthController < ActionController::API
  def show
    checks = { db: db_check, redis: redis_check }
    render json: checks, status: checks[:db] ? :ok : :service_unavailable
  end

  private

  def db_check
    ActiveRecord::Base.connection.execute('SELECT 1')
    true
  rescue StandardError
    false
  end

  def redis_check
    $redis.ping == 'PONG' # rubocop:disable Style/GlobalVars
  rescue StandardError
    false
  end
end
