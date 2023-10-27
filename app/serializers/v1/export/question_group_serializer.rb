# frozen_string_literal: true

class V1::Export::QuestionGroupSerializer < ActiveModel::Serializer
  attributes :title, :position, :type

  has_many :questions, serializer: V1::Export::QuestionSerializer

  attribute :version do
    QuestionGroup::CURRENT_VERSION
  end
end
