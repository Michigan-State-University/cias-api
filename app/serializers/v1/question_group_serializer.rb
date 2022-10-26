# frozen_string_literal: true

class V1::QuestionGroupSerializer < V1Serializer
  attributes :session_id, :title, :position, :type

  has_many :questions, { serializer: V1::QuestionSerializer,
                         include: %i[image_attachment image_blob] }
end
