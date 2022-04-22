# frozen_string_literal: true

class V1::ReportTemplate::SectionSerializer < V1Serializer
  attributes :formula, :report_template_id, :position

  has_many :variants, serializer: V1::ReportTemplate::Section::VariantSerializer
end
