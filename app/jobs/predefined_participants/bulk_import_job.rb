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
    Rails.logger.info "[#{self.class.name}] Starting: researcher_id=#{researcher.id} intervention_id=#{intervention.id} rows=#{payload.size}"

    # Narrow rescue: a mailer failure on the success path must NOT trigger the error email.
    begin
      result = V1::Intervention::PredefinedParticipants::BulkImportService.call(
        researcher, intervention, payload
      )
    rescue StandardError => e
      Rails.logger.warn "[#{self.class.name}] Service raised: researcher_id=#{researcher.id} " \
                        "intervention_id=#{intervention.id} error=#{e.class}"
      Sentry.capture_exception(e)
      send_email(researcher, :bulk_import_error) { BulkImportMailer.bulk_import_error(researcher, intervention) }
      return
    ensure
      # Inner rescue is load-bearing: destroy failure escaping `perform` would
      # trigger `retry_on` and reprocess the still-existing row → duplicates.
      begin
        payload_record&.destroy
      rescue StandardError => e
        Rails.logger.error "[#{self.class.name}] Payload destroy failed: payload_id=#{payload_id} error=#{e.class}"
        Sentry.capture_exception(e)
      end
    end

    Rails.logger.info "[#{self.class.name}] Completed: researcher_id=#{researcher.id} intervention_id=#{intervention.id} " \
                      "total=#{result[:total]} participants_created=#{result[:participants_created]} " \
                      "ra_completed=#{result[:ra_completed]} ra_partial=#{result[:ra_partial]} failed=#{result[:failed]}"
    send_email(researcher, :bulk_import_result) { BulkImportMailer.bulk_import_result(researcher, intervention, result) }
  end

  private

  def send_email(researcher, action)
    unless researcher.email_notification
      Rails.logger.info "[#{self.class.name}] Email skipped (email_notification=false): researcher_id=#{researcher.id} action=#{action}"
      return
    end

    yield.deliver_now
  rescue StandardError => e
    Rails.logger.warn "[#{self.class.name}] Mailer failed: researcher_id=#{researcher.id} action=#{action} error=#{e.class}"
    Sentry.capture_exception(e)
  end
end
