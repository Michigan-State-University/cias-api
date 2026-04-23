# frozen_string_literal: true

class PredefinedParticipants::BulkImportJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: false

  def perform(payload_id)
    payload_record = BulkImportPayload.find_by(id: payload_id)
    return if payload_record.blank?

    researcher = payload_record.researcher
    intervention = payload_record.intervention
    return if researcher.blank? || intervention.blank?

    payload = payload_record.payload

    # Narrow rescue: a mailer failure on the success path must NOT trigger the error email.
    begin
      result = V1::Intervention::PredefinedParticipants::BulkImportService.call(
        researcher, intervention, payload
      )
    rescue StandardError => e
      Sentry.capture_exception(e)
      send_email(researcher) { BulkImportMailer.bulk_import_error(researcher, intervention) }
      return
    ensure
      # Inner rescue is load-bearing: destroy failure escaping `perform` would
      # trigger `retry_on` and reprocess the still-existing row → duplicates.
      begin
        payload_record&.destroy
      rescue StandardError => e
        Sentry.capture_exception(e)
      end
    end

    send_email(researcher) { BulkImportMailer.bulk_import_result(researcher, intervention, result) }
  end

  private

  def send_email(researcher)
    return unless researcher.email_notification

    yield.deliver_now
  rescue StandardError => e
    Sentry.capture_exception(e)
  end
end
