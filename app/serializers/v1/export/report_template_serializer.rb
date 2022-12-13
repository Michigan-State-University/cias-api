# frozen_string_literal: true

class V1::Export::ReportTemplateSerializer < ActiveModel::Serializer
  include FileHelper

  attributes :name, :report_for, :summary, :original_text

  has_many :sections, serializer: V1::Export::ReportTemplateSectionSerializer

  attribute :logo do
    export_file(object.logo)
  end

  attribute :version do
    ReportTemplate::CURRENT_VERSION
  end
end
