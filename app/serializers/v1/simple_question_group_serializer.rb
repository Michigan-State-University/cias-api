# frozen_string_literal: true

class V1::SimpleQuestionGroupSerializer < V1Serializer
  attributes :session_id, :title, :position, :type
end
