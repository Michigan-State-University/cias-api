# frozen_string_literal: true

class V1::ReportTemplates::GeneratePdfPreview
  def self.call(report_template, current_v1_user)
    new(report_template, current_v1_user).call
  end

  def initialize(report_template, current_v1_user)
    @report_template = report_template
    @current_v1_user = current_v1_user
  end

  def call
    return unless current_v1_user.email_notification

    I18n.with_locale(report_template.session.language_code) do
      ReportTemplateMailer.template_preview(
        email: current_v1_user.email,
        report_template: report_template,
        report_template_preview_pdf: render_pdf_report
      ).deliver_now
    end
  end

  private

  attr_reader :report_template, :current_v1_user

  def variants_to_preview
    @variants_to_preview ||= report_template.variants.to_preview.
      order(created_at: :asc).
      includes(image_attachment: :blob)
  end

  def render_pdf_report
    V1::RenderPdfReport.call(
      report_template: report_template,
      variants_to_generate: variants_to_preview
    )
  end
end
