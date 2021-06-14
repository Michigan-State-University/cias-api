# frozen_string_literal: true

class V1::QuestionSerializer < V1Serializer
  attributes :type, :question_group_id, :settings, :position, :title, :subtitle, :narrator, :image_url, :img_description, :video_url, :formula, :body

  attribute :image_url do |object|
    polymorphic_url(object.image) if object.image.attached?
  end

  attribute :img_description do |object|
    object.image_blob.description if object.image_blob.present?
  end
end
