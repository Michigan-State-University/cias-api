# frozen_string_literal: true

class ParticipantUpload < ApplicationRecord
  SCAN_STATUSES = %w[pending clean deleted].freeze
  REMOVED_STATUSES = %w[deleted].freeze
  SCAN_WINDOW = 25.minutes
  MALWARE_DELETION_REASON = 'MALWARE_DETECTED'
  UNREADABLE_DELETION_REASON = 'SCANNER_CANNOT_INSPECT'
  CONFIGURATION_DELETION_REASON = 'SCANNER_CONFIGURATION_ERROR'

  DELETION_REASON_BY_VERDICT = {
    'infected' => MALWARE_DELETION_REASON,
    'scanner_misconfigured' => CONFIGURATION_DELETION_REASON
  }.freeze

  MODERATION_STATUSES = %w[pending completed skipped failed].freeze

  MODERATION_CATEGORIES = [
    'Alcohol',
    'Drugs & Tobacco',
    'Explicit',
    'Gambling',
    'Hate Symbols',
    'Non-Explicit Nudity of Intimate parts and Kissing',
    'Rude Gestures',
    'Swimwear or Underwear',
    'Violence',
    'Visually Disturbing'
  ].freeze

  UNSUPPORTED_FORMAT_SKIP_REASON = 'UNSUPPORTED_FORMAT'
  TOO_LARGE_SKIP_REASON = 'TOO_LARGE'
  MODERATION_DISABLED_SKIP_REASON = 'MODERATION_DISABLED'
  FILE_REMOVED_SKIP_REASON = 'FILE_REMOVED_BY_SECURITY_SCAN'

  has_paper_trail skip: %i[original_filename original_filename_ciphertext description description_ciphertext
                           moderation_labels moderation_labels_ciphertext]
  audited except: %i[original_filename original_filename_ciphertext description description_ciphertext
                     moderation_labels moderation_labels_ciphertext]
  has_encrypted :original_filename, :description
  has_encrypted :moderation_labels, type: :json

  belongs_to :user_session, inverse_of: :participant_uploads
  belongs_to :question, inverse_of: :participant_uploads

  has_one_attached :file, dependent: :purge_later

  validates :original_filename, presence: true
  validates :scan_status, inclusion: { in: SCAN_STATUSES }
  validates :moderation_status, inclusion: { in: MODERATION_STATUSES }
  validates :content_type_detected, inclusion: { in: Settings.participant_uploads.allowed_content_types },
                                    unless: :removed_by_scanner?
  validates :file,
            attached: true,
            size: { less_than_or_equal_to: Settings.participant_uploads.max_size_mb.megabytes },
            unless: :removed_by_scanner?

  scope :not_removed, -> { where.not(scan_status: REMOVED_STATUSES) }
  scope :counts_against_limit, -> { not_removed.where("scan_status <> 'pending' OR created_at > ?", SCAN_WINDOW.ago) }

  def served_inline?
    content_type_detected.in?(Settings.participant_uploads.inline_preview_content_types)
  end

  def servable?
    scan_status == 'clean'
  end

  def mark_clean!
    update!(scan_status: 'clean')
    ParticipantUploads::ModerationJob.perform_later(id)
  end

  def moderatable_format?
    content_type_detected.in?(Settings.participant_uploads.moderation.content_types)
  end

  def complete_moderation!(labels, model_version)
    update!(moderation_status: 'completed', moderation_labels: labels,
            moderation_model_version: model_version, moderated_at: Time.current)
  end

  def skip_moderation!(reason)
    update!(moderation_status: 'skipped', moderation_skip_reason: reason,
            moderation_labels: [], moderated_at: Time.current)
  end

  def fail_moderation!
    update!(moderation_status: 'failed', moderation_labels: [], moderated_at: Time.current)
  end

  def close!(verdict)
    update!(
      {
        scan_status: 'deleted',
        deleted_at: Time.current,
        deletion_reason: DELETION_REASON_BY_VERDICT.fetch(verdict.to_s, UNREADABLE_DELETION_REASON)
      }.merge(moderation_closure)
    )
    file.purge_later
    V1::ParticipantUploads::RemovalReport.call(self)
  end

  def removed_by_scanner?
    scan_status.in?(REMOVED_STATUSES)
  end

  private

  def moderation_closure
    return {} unless moderation_status == 'pending'

    { moderation_status: 'skipped', moderation_skip_reason: FILE_REMOVED_SKIP_REASON,
      moderation_labels: [], moderated_at: Time.current }
  end
end
