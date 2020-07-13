# frozen_string_literal: true

class V1Serializer
  extend ActionDispatch::Routing::UrlFor
  extend Rails.application.routes.url_helpers
  include FastJsonapi::ObjectSerializer
  include Rails.application.routes.url_helpers
end
