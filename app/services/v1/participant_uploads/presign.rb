# frozen_string_literal: true

class V1::ParticipantUploads::Presign
  REASONS = {
    type: 'FILE_TYPE_NOT_ALLOWED',
    size: 'FILE_TOO_LARGE',
    count: 'TOO_MANY_FILES',
    missing: 'FILE_MISSING'
  }.freeze

  NEUTRAL_CONTENT_TYPE = 'application/octet-stream'
  KEY_PREFIX = 'participant_uploads'
  EXPIRES_IN = 30.minutes

  def self.purpose(user_session, question)
    "participant_upload_#{user_session.id}_#{question.id}"
  end

  def self.call(user_session, question, params)
    new(user_session, question, params).call
  end

  def initialize(user_session, question, params)
    @user_session = user_session
    @question = question
    @params = params
  end

  def call
    refuse!(REASONS[:missing]) if declared_filename.blank? || checksum.blank? || byte_size.zero?
    refuse!(REASONS[:count]) if limit_reached?
    refuse!(REASONS[:size]) if too_large?
    refuse!(REASONS[:type]) unless allowed_extension?

    direct_upload_for(blob)
  end

  private

  attr_reader :user_session, :question, :params

  def blob
    @blob ||= ActiveStorage::Blob.create_before_direct_upload!(
      key: "#{KEY_PREFIX}/#{ActiveStorage::Blob.generate_unique_secure_token}",
      filename: neutral_filename,
      byte_size: byte_size,
      checksum: checksum,
      content_type: NEUTRAL_CONTENT_TYPE
    )
  end

  def direct_upload_for(blob)
    {
      signed_id: blob.signed_id(purpose: self.class.purpose(user_session, question), expires_in: EXPIRES_IN),
      direct_upload: {
        url: blob.service_url_for_direct_upload(expires_in: EXPIRES_IN),
        headers: blob.service_headers_for_direct_upload
      }
    }
  end

  def declared_filename
    params[:filename].to_s
  end

  def byte_size
    params[:byte_size].to_i
  end

  def checksum
    params[:checksum].to_s
  end

  def extension
    File.extname(declared_filename).delete('.').downcase
  end

  def neutral_filename
    "upload_#{SecureRandom.uuid}.#{extension}"
  end

  def allowed_extension?
    extension.in?(Settings.participant_uploads.accepted_extensions)
  end

  def too_large?
    byte_size > Settings.participant_uploads.max_size_mb.megabytes
  end

  def limit_reached?
    user_session.participant_uploads.where(question_id: question.id).counts_against_limit.count >=
      Settings.participant_uploads.max_files_per_question
  end

  def refuse!(reason)
    raise ComplexException.new(
      I18n.t('participant_uploads.errors.rejected'),
      { reason: reason },
      :unprocessable_content
    )
  end
end
