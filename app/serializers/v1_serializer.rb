# frozen_string_literal: true

class V1Serializer
  include FastJsonapi::ObjectSerializer
  cache_options enabled: true, cache_length: ENV.fetch('CACHE_DURATION_VALID') { 12 }.to_i.hours
end
