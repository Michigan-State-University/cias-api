# frozen_string_literal: true

class GeneratedReportMailer < ApplicationMailer
  def new_report_available(email, number_of_generated_reports = 1)
    @number_of_generated_reports = number_of_generated_reports

    mail(
      to: email,
      subject: I18n.t('generated_report_mailer.new_report_available.subject')
    )
  end
end
