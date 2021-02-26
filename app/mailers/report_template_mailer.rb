# frozen_string_literal: true

class ReportTemplateMailer < ApplicationMailer
  def template_preview(email:, report_template:, report_template_preview_pdf:)
    @report_template      = report_template
    attachments[filename] = report_template_preview_pdf

    mail(
      to: email,
      subject: I18n.t('report_template_mailer.template_preview.subject',
                      report_template_name: report_template.name)
    )
  end

  private

  def filename
    "#{@report_template.name}_preview_#{I18n.l(Time.current, format: :file)}.pdf"
  end
end
