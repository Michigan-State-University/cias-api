# frozen_string_literal: true

class V1Serializer
  extend ActionDispatch::Routing::UrlFor
  extend Rails.application.routes.url_helpers
  include FastJsonapi::ObjectSerializer
  include Rails.application.routes.url_helpers
  cache_options enabled: true, cache_length: ENV.fetch('CACHE_DURATION_VALID') { 12 }.to_i.hours
end
