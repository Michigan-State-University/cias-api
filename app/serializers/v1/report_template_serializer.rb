# frozen_string_literal: true

class V1::ReportTemplateSerializer < V1Serializer
  attributes :name, :report_for, :logo_url, :summary, :session_id, :original_text
  has_many :sections, serializer: V1::ReportTemplate::SectionSerializer
  has_many :variants, serializer: V1::ReportTemplate::Section::VariantSerializer

  attribute :logo_url do |object|
    url_for(object.logo) if object.logo.attached?
  end
end
