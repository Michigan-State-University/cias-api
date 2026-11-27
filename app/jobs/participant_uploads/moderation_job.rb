# frozen_string_literal: true

class ParticipantUploads::ModerationJob < ApplicationJob
  self.enqueue_after_transaction_commit = true

  MAX_ATTEMPTS = 5
  RETRY_WAIT = 1.minute

  retry_on StandardError, wait: RETRY_WAIT, attempts: MAX_ATTEMPTS

  def perform(upload_id)
    upload = ParticipantUpload.find_by(id: upload_id)
    return if upload.nil? || upload.moderation_status != 'pending'
    return upload.skip_moderation!(ParticipantUpload::MODERATION_DISABLED_SKIP_REASON) unless enabled?
    return upload.skip_moderation!(skip_reason(upload)) if skip_reason(upload)

    detect(upload)
  end

  private

  def enabled?
    Settings.participant_uploads.moderation.enabled
  end

  def skip_reason(upload)
    return ParticipantUpload::UNSUPPORTED_FORMAT_SKIP_REASON unless upload.moderatable_format?
    return ParticipantUpload::TOO_LARGE_SKIP_REASON if upload.byte_size > V1::ParticipantUploads::ModerationAdapter::MAX_IMAGE_BYTES

    nil
  end

  def detect(upload)
    result = V1::ParticipantUploads::ModerationAdapter.new.detect(upload.file.blob)
    upload.complete_moderation!(result.labels, result.model_version)
  rescue StandardError => e
    raise e if executions < MAX_ATTEMPTS

    Sentry.capture_exception(e, extra: { participant_upload_id: upload.id })
    upload.fail_moderation!
  end
end
