# frozen_string_literal: true

class V1::SmsPlan::VariantSerializer < V1Serializer
  attributes :formula_match, :content, :original_text, :position

  attribute :image_url do |object|
    url_for(object.image) if object.image.attached?
  end
end
