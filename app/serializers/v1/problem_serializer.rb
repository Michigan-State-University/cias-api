# frozen_string_literal: true

class V1::ProblemSerializer < V1Serializer
  attributes :name, :interventions, :allow_guests, :status
end
