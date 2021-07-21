# frozen_string_literal: true

class SendNewReportNotificationJob < ApplicationJob
  queue_as :reports

  def perform(email, number_of_generated_reports = 1)
    return unless User.find_by(email: email)&.email_notification

    GeneratedReportMailer.new_report_available(email, number_of_generated_reports).deliver_now if number_of_generated_reports > 0
  end
end
