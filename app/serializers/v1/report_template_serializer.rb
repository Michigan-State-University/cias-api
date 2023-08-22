# frozen_string_literal: true

class V1::ReportTemplateSerializer < V1Serializer
  attributes :name, :report_for, :logo_url, :cover_letter_custom_logo_url, :summary, :session_id, :original_text,
             :has_cover_letter, :cover_letter_logo_type, :cover_letter_description, :cover_letter_sender,
             :original_text, :is_duplicated_from_other_session, :duplicated_from_other_session_warning_dismissed
  has_many :sections, serializer: V1::ReportTemplate::SectionSerializer
  has_many :variants, serializer: V1::ReportTemplate::Section::VariantSerializer

  attribute :logo_url do |object|
    url_for(object.logo) if object.logo.attached?
  end

  attribute :cover_letter_custom_logo_url do |object|
    url_for(object.cover_letter_custom_logo) if object.cover_letter_custom_logo.attached?
  end
end
