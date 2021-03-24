# frozen_string_literal: true

# rubocop:disable all
if Rails.env.development? || ENV['SIDEKIQ_WEB_INTERFACE'] == '1'
  SecureHeaders::Configuration.default do |config|
    config.hsts = 'max-age=31536000; includeSubDomains'
    config.x_frame_options = 'SAMEORIGIN'
    config.x_content_type_options = 'nosniff'
    config.x_xss_protection = '1; mode=block'
    config.x_download_options = 'noopen'
    config.referrer_policy = %w[origin-when-cross-origin strict-origin-when-cross-origin]
    config.csp = {
      # directive values: these values will directly translate into source directives
      default_src: %w[http: https: data: 'unsafe-inline'],
      script_src: %w[http: https: data: 'unsafe-inline'],
      img_src: %w[http: https: data: 'unsafe-inline'],
      frame_src: %w[http: https: data: 'unsafe-inline']
    }
  end
else
  SecureHeaders::Configuration.default do |config|
    config.hsts = 'max-age=31536000; includeSubDomains'
    config.x_frame_options = 'DENY'
    config.x_content_type_options = 'nosniff'
    config.x_xss_protection = '1; mode=block'
    config.x_download_options = 'noopen'
    config.x_permitted_cross_domain_policies = 'none'
    config.referrer_policy = %w[origin-when-cross-origin strict-origin-when-cross-origin]
    config.csp = {
      # directive values: these values will directly translate into source directives
      default_src: %w['none'],
      script_src: %w['self']
    }
  end
end
# rubocop:enable all
