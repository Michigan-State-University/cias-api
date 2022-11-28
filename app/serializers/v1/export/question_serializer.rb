# frozen_string_literal: true

class V1::Export::QuestionSerializer < ActiveModel::Serializer
  include FileHelper
  attributes :type, :settings, :position, :title, :subtitle, :narrator, :video_url, :formulas, :body, :original_text

  attribute :duplicated do
    true
  end

  attribute :image do
    export_file(object.image)
  end

  attribute :version do
    Question::CURRENT_VERSION
  end
end
