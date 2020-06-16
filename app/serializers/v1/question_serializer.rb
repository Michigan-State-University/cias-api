# frozen_string_literal: true

class V1::QuestionSerializer < V1Serializer
  attributes :type, :intervention_id, :order, :title, :subtitle, :image_url, :video_url, :formula, :body

  attribute :image_url do |object|
    polymorphic_url(object.image) if object.image.attached?
  end
end
