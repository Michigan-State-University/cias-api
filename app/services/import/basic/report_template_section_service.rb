# frozen_string_literal: true

class Import::Basic::ReportTemplateSectionService
  include ImportOperations
  def self.call(report_template_id, section_hash)
    new(
      report_template_id,
      section_hash.except(:version)
    ).call
  end

  def initialize(report_template_id, section_hash)
    @report_template_id = report_template_id
    @section_hash = section_hash
  end

  attr_reader :section_hash, :report_template_id

  def call
    variants = section_hash.delete(:variants)
    section = ReportTemplate::Section.create!(section_hash.merge({ report_template_id: report_template_id }))
    variants&.each do |variant_hash|
      get_import_service_class(variant_hash, ReportTemplate::Section::Variant).call(section.id, variant_hash)
    end
  end
end
