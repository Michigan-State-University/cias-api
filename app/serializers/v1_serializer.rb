# frozen_string_literal: true

class V1Serializer
  extend ActionDispatch::Routing::UrlFor
  extend Rails.application.routes.url_helpers
  include JSONAPI::Serializer
  include Rails.application.routes.url_helpers
end
