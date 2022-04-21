# frozen_string_literal: true

class V1::CatMh::TimeFrameSerializer < V1Serializer
  attributes :id, :timeframe_id, :description, :short_name
end
