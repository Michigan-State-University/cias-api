# frozen_string_literal: true

module InterfaceSerializer
  extend ActiveSupport::Concern
  included do
    cache_options enabled: true, cache_length: ENV.fetch('CACHE_DURATION_VALID') { 12 }.to_i.hours
  end
end
