# frozen_string_literal: true

Raven.configure do |config|
  config.environments = %w[production]
  config.dsn = ENV['SENTRY_DSN']
  config.async = lambda do |event|
    LogJob::ErrorBeacon.perform_later(event)
  end
  config.sanitize_fields = Rails.application.config.filter_parameters.map(&:to_s)
  config.excluded_exceptions += %w[ActionController::InvalidAuthenticityToken
                                   ActionController::InvalidCrossOriginRequest
                                   ActionController::UnknownFormat
                                   ActionDispatch::RemoteIp::IpSpoofAttackError
                                   CanCan::AccessDenied]
end
