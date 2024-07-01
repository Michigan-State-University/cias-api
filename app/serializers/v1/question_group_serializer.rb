# frozen_string_literal: true

class V1::QuestionGroupSerializer < V1Serializer
  attributes :session_id, :title, :position, :type, :sms_schedule, :formulas

  has_many :questions, serializer: V1::QuestionSerializer
end
