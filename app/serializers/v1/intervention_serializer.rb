# frozen_string_literal: true

class V1::InterventionSerializer < V1Serializer
  attributes :settings, :status, :position, :allow_guests, :name, :slug, :formula, :body, :problem_id
end
