# frozen_string_literal: true

class GeneratedReportMailer < ApplicationMailer
  def new_report_available(email)
    mail(
      to: email,
      subject: I18n.t('generated_report_mailer.new_report_available.subject')
    )
  end
end
