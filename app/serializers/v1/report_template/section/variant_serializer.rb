# frozen_string_literal: true

class V1::ReportTemplate::Section::VariantSerializer < V1Serializer
  attributes :preview, :formula_match, :title, :content, :report_template_section_id, :original_text, :position

  attribute :image_url do |object|
    url_for(object.image) if object.image.attached?
  end
end
