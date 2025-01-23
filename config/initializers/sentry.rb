# frozen_string_literal: true

require "active_support/parameter_filter"

Sentry.init do |config|
  config.enabled_environments = %w[production]
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = %i[active_support_logger http_logger]

  # Set tracesSampleRate to 1.0 to capture 100%
  # of transactions for performance monitoring.
  # We recommend adjusting this value in production
  config.traces_sample_rate = 1.0
  # or
  config.traces_sampler = lambda do |_context|
    true
  end

  filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
  config.before_send = lambda do |event, _hint|
    filter.filter(event.to_hash)
  end

  config.excluded_exceptions += %w[ActionController::InvalidAuthenticityToken
                                   ActionController::InvalidCrossOriginRequest
                                   CanCan::AccessDenied]
end
