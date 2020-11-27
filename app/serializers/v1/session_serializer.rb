# frozen_string_literal: true

class V1::SessionSerializer < V1Serializer
  attributes :settings, :position, :name, :schedule, :schedule_payload, :schedule_at, :slug, :formula, :body, :intervention_id
end
