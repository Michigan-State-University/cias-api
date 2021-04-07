# frozen_string_literal: true

class V1::GeneratedReports::Create
  def self.call(report_template, user_session, dentaku_calculator)
    new(report_template, user_session, dentaku_calculator).call
  end

  def initialize(report_template, user_session, dentaku_service)
    @report_template = report_template
    @user_session = user_session
    @dentaku_service = dentaku_service
  end

  def call
    variants_to_generate =
      report_template.sections.map do |section|
        dentaku_service.evaluate(section.formula, section.variants)
      end

    variants_to_generate.compact!

    return if variants_to_generate.blank?

    insert_name_into_variants(variants_to_generate)

    GeneratedReport.transaction do
      generated_report = GeneratedReport.create!(
        name: report_name,
        user_session_id: user_session.id,
        report_template_id: report_template.id,
        report_for: report_template.report_for
      )

      MetaOperations::FilesKeeper.new(
        stream: render_pdf_report(variants_to_generate),
        add_to: generated_report, filename: report_name,
        macro: :pdf_report, ext: :pdf, type: 'application/pdf'
      ).execute
    end
  end

  private

  attr_reader :report_template, :user_session, :dentaku_service

  def render_pdf_report(variants_to_generate)
    V1::RenderPdfReport.call(
      report_template: report_template,
      variants_to_generate: variants_to_generate
    )
  end

  def name_variable
    @name_variable ||= Answer::Name.find_by(
      user_session_id: user_session.id
    )&.body_data&.first&.dig('value').presence&.dig('name')
  end

  def insert_name_into_variants(variants_to_generate)
    variants_to_generate.each { |variant| variant.content.gsub!('.:name:.', name_variable.presence || 'Participant') }
  end

  def report_name
    @report_name ||= "Report #{I18n.l(Time.current, format: :report_file)}"
  end
end
