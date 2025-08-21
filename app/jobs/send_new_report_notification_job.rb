# frozen_string_literal: true

class SendNewReportNotificationJob < ApplicationJob
  queue_as :reports

  def perform(email, locale = 'en', number_of_generated_reports = 1)
    return unless User.find_by(email: email)&.email_notification

    GeneratedReportMailer.with(locale: locale).new_report_available(email, number_of_generated_reports).deliver_now if number_of_generated_reports.positive?
  end
end
