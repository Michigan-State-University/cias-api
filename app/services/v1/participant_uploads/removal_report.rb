# frozen_string_literal: true

class V1::ParticipantUploads::RemovalReport
  def self.call(upload) = new(upload).call

  def initialize(upload)
    @upload = upload
  end

  def call
    Rails.logger.warn("participant_upload #{upload.id} removed: #{upload.deletion_reason}")
    return if upload.deletion_reason == ParticipantUpload::MALWARE_DELETION_REASON

    Sentry.capture_message(
      message,
      level: level,
      extra: {
        participant_upload_id: upload.id,
        deletion_reason: upload.deletion_reason,
        scan_attempts: upload.scan_attempts
      }
    )
  end

  private

  attr_reader :upload

  def misconfigured?
    upload.deletion_reason == ParticipantUpload::CONFIGURATION_DELETION_REASON
  end

  def message
    return 'participant upload removed because the scanner could not read it' if misconfigured?

    'participant upload removed without a scan verdict'
  end

  def level
    misconfigured? ? :error : :warning
  end
end
