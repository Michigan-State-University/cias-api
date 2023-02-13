# frozen_string_literal: true

class V1::Export::ReportTemplateSectionSerializer < ActiveModel::Serializer
  attributes :formula, :position

  has_many :variants, serializer: V1::Export::ReportTemplateVariantSerializer

  attribute :version do
    ReportTemplate::Section::CURRENT_VERSION
  end
end
