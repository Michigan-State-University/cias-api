# frozen_string_literal: true

class ParticipantUploads::ScanJob < ApplicationJob
  self.enqueue_after_transaction_commit = true

  MAX_ATTEMPTS = 10
  ERROR_RETRY_WAIT = 1.minute
  PENDING_RETRY_WAIT = 15.seconds
  MAX_PENDING_ATTEMPTS = 80

  CONFIGURATION_ERRORS = [
    V1::ParticipantUploads::Scanner::UnknownScannerError,
    V1::ParticipantUploads::Scanner::InsecureScannerError,
    V1::ParticipantUploads::GuardDutyS3Adapter::UnsupportedServiceError,
    V1::ParticipantUploads::GuardDutyS3Adapter::ScanStatusUnavailableError
  ].freeze

  retry_on StandardError, wait: ERROR_RETRY_WAIT, attempts: MAX_ATTEMPTS

  def perform(upload_id)
    upload = ParticipantUpload.find_by(id: upload_id)
    return if upload.nil? || upload.scan_status != 'pending'

    verdict = scan(upload)

    case verdict
    when :clean then upload.mark_clean!
    when :pending then wait_for_verdict(upload)
    else upload.close!(verdict)
    end
  end

  private

  def scan(upload)
    upload.update!(scan_attempts: upload.scan_attempts + 1)
    inspect_file(upload)
  end

  def inspect_file(upload)
    V1::ParticipantUploads::Scanner.build.scan(upload.file.blob)
  rescue *CONFIGURATION_ERRORS => e
    Sentry.capture_exception(e, level: :error)
    raise e if executions < MAX_ATTEMPTS

    :scanner_misconfigured
  rescue StandardError => e
    raise e if executions < MAX_ATTEMPTS

    Sentry.capture_exception(e)
    :unreadable
  end

  def wait_for_verdict(upload)
    return upload.close!(:unreadable) if upload.scan_attempts >= MAX_PENDING_ATTEMPTS

    self.class.set(wait: PENDING_RETRY_WAIT).perform_later(upload.id)
  end
end
