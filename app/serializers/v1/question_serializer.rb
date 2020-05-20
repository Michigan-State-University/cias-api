# frozen_string_literal: true

class V1::QuestionSerializer < V1Serializer
  attributes :type, :intervention_id, :previous_id, :title, :subtitle, :body
end
