# frozen_string_literal: true

class V1::ProblemSerializer < V1Serializer
  attributes :name, :user_id, :interventions, :allow_guests, :status
end
