# frozen_string_literal: true

class ParticipantUploads::ReconcileJob < ApplicationJob
  STALE_AFTER = ParticipantUpload::SCAN_WINDOW
  IDLE_AFTER = ParticipantUploads::ScanJob::ERROR_RETRY_WAIT * 5

  def perform
    ParticipantUpload.where(scan_status: 'pending', created_at: ..STALE_AFTER.ago,
                            updated_at: ..IDLE_AFTER.ago).with_attached_file.find_each do |upload|
      reconcile(upload)
    end

    purge_closed_uploads
    requeue_stalled_moderation
  end

  private

  def purge_closed_uploads
    ParticipantUpload.where(scan_status: 'deleted', updated_at: ..IDLE_AFTER.ago)
                     .with_attached_file.find_each do |upload|
      next unless upload.file.attached?

      upload.file.purge_later
    rescue StandardError => e
      Sentry.capture_exception(e, extra: { participant_upload_id: upload.id })
    end
  end

  def requeue_stalled_moderation
    ParticipantUpload.where(scan_status: 'clean', moderation_status: 'pending',
                            updated_at: ..IDLE_AFTER.ago).find_each do |upload|
      ParticipantUploads::ModerationJob.perform_later(upload.id)
    rescue StandardError => e
      Sentry.capture_exception(e, extra: { participant_upload_id: upload.id })
    end
  end

  def reconcile(upload)
    return upload.close!(:unreadable) unless stored?(upload)
    return upload.close!(:unreadable) if attempts_exhausted?(upload)

    ParticipantUploads::ScanJob.perform_later(upload.id)
  rescue StandardError => e
    Sentry.capture_exception(e, extra: { participant_upload_id: upload.id })
  end

  def attempts_exhausted?(upload)
    upload.scan_attempts >= ParticipantUploads::ScanJob::MAX_PENDING_ATTEMPTS
  end

  def stored?(upload)
    blob = upload.file.blob
    return false if blob.nil?

    blob.service.exist?(blob.key)
  end
end
