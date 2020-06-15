# frozen_string_literal: true

class V1::AnswerSerializer < V1Serializer
  attributes :type, :question, :user, :body
end
