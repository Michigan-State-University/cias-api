# frozen_string_literal: true

require 'active_support/parameter_filter'

Sentry.init do |config|
  config.enabled_environments = %w[production]
  config.dsn = ENV.fetch('SENTRY_DSN', nil)
  config.breadcrumbs_logger = %i[active_support_logger http_logger]
  config.send_default_pii = false

  # Set tracesSampleRate to 1.0 to capture 100%
  # of transactions for performance monitoring.
  # We recommend adjusting this value in production
  config.traces_sample_rate = 1.0
  # or
  config.traces_sampler = lambda do |_context|
    true
  end

  filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

  # ActiveRecord insert_all compiles its rows into the SQL text, so db.sql spans and sql.active_record
  # breadcrumbs would carry every inserted value (SmsLinksUser slugs are link credentials).
  sql_values = /\bVALUES\b.*/im
  scrub_sql = ->(sql) { sql.is_a?(String) ? sql.sub(sql_values, 'VALUES [FILTERED]') : sql }

  # before_send never runs for transaction events (sentry-ruby client.rb), yet the scope copies its breadcrumbs onto
  # them, so SQL has to be scrubbed at capture to cover both kinds of event. Keys are symbols here.
  config.before_breadcrumb = lambda do |crumb, _hint|
    crumb.data[:sql] = scrub_sql.call(crumb.data[:sql]) if crumb.data.is_a?(Hash) && crumb.data.key?(:sql)
    crumb
  end

  config.before_send = lambda do |event, _hint|
    filter.filter(event.to_hash)
  end

  config.before_send_transaction = lambda do |event, _hint|
    Array(event.spans).each do |span|
      span[:description] = scrub_sql.call(span[:description]) if span[:op].to_s.start_with?('db.')
    end
    event
  end

  config.excluded_exceptions += %w[ActionController::InvalidAuthenticityToken
                                   ActionController::InvalidCrossOriginRequest
                                   CanCan::AccessDenied]
end
