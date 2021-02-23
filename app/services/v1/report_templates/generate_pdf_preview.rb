# frozen_string_literal: true

class V1::ReportTemplates::GeneratePdfPreview
  def self.call(report_template, current_v1_user)
    new(report_template, current_v1_user).call
  end

  def initialize(report_template, current_v1_user)
    @action_controller = ActionController::Base.new
    @report_template   = report_template
    @current_v1_user   = current_v1_user
  end

  def call
    ReportTemplateMailer.template_preview(
      email: current_v1_user.email,
      report_template: report_template,
      report_template_preview_pdf: render_preview_pdf
    ).deliver_now
  end

  private

  attr_reader :report_template, :action_controller, :current_v1_user

  def variants_to_preview
    @variants_to_preview ||= report_template.variants.to_preview.
      order(created_at: :asc).
      includes(image_attachment: :blob)
  end

  def render_preview_pdf
    WickedPdf.new.pdf_from_string(
      report_template_html,
      margin: {
        top: 25,
        bottom: 25,
        right: 15,
        left: 15
      },
      header: {
        content: report_header_html
      }
    )
  end

  def report_template_html
    action_controller.render_to_string(
      template: 'report_templates/report_preview.html.erb',
      locals: {
        report_template: report_template,
        variants: variants_to_preview
      }
    )
  end

  def report_header_html
    action_controller.render_to_string(
      template: 'report_templates/report_header.html.erb',
      locals: {
        report_template: report_template
      }
    )
  end
end
