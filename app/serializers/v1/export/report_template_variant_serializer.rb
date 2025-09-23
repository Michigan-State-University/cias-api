# frozen_string_literal: true

class V1::Export::ReportTemplateVariantSerializer < ActiveModel::Serializer
  include FileHelper

  attributes :preview, :formula_match, :title, :content, :original_text

  attribute :image do
    export_file(object.image)
  end

  attribute :version do
    ReportTemplate::Section::Variant::CURRENT_VERSION
  end
end
