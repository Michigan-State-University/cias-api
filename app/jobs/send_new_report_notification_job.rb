# frozen_string_literal: true

class SendNewReportNotificationJob < ApplicationJob
  queue_as :reports

  def perform(email)
    GeneratedReportMailer.new_report_available(email).deliver_now
  end
end
