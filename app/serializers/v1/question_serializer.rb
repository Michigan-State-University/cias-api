# frozen_string_literal: true

class V1::QuestionSerializer < V1Serializer
  attributes :type, :intervention_id, :order, :title, :subtitle, :video, :formula, :body
end
