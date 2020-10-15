# frozen_string_literal: true

class V1::QuestionGroupSerializer < V1Serializer
  attributes :intervention_id, :title, :default, :position
end
