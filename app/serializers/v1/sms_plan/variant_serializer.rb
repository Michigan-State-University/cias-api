# frozen_string_literal: true

class V1::SmsPlan::VariantSerializer < V1Serializer
  include FileHelper

  attributes :formula_match, :content, :original_text, :position

  attribute :attachment do |object|
    map_file_data(object.attachment) if object.attachment.attached?
  end
end
