# frozen_string_literal: true

class Import::Basic::ReportTemplateService
  include ImportOperations

  def self.call(session_id, report_template_hash)
    new(
      session_id,
      report_template_hash.except(:version)
    ).call
  end

  def initialize(session_id, report_template_hash)
    @report_template_hash = report_template_hash
    @session_id = session_id
    @logo = report_template_hash.delete(:logo)
    @cover_letter_custom_logo = report_template_hash.delete(:cover_letter_custom_logo)
  end

  attr_reader :report_template_hash, :session_id, :logo, :cover_letter_custom_logo

  def call
    report_template_sections = report_template_hash.delete(:sections)
    report_template = ReportTemplate.create!(report_template_hash.merge({ session_id: session_id }))
    import_file_directly(report_template, :logo, logo) if logo.present?
    import_file_directly(report_template, :cover_letter_custom_logo, cover_letter_custom_logo) if logo.present?
    report_template_sections&.each do |report_template_section_hash|
      get_import_service_class(report_template_section_hash, ReportTemplate::Section).call(report_template.id, report_template_section_hash)
    end
    report_template
  end
end
