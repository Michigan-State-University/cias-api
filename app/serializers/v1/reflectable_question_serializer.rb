# frozen_string_literal: true

class V1::ReflectableQuestionSerializer < V1Serializer
  attributes :type, :question_group_id, :subtitle, :body

  attribute :session_id do |object|
    object.session.id
  end
end
