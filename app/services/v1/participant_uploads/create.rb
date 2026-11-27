# frozen_string_literal: true

class V1::ParticipantUploads::Create
  REASONS = V1::ParticipantUploads::Presign::REASONS

  def self.call(user_session, question, params)
    new(user_session, question, params).call
  end

  def initialize(user_session, question, params)
    @user_session = user_session
    @question = question
    @params = params
  end

  def call
    refuse!(REASONS[:missing]) if params[:original_filename].blank?
    refuse!(REASONS[:missing]) unless uploaded_blob?
    refuse!(REASONS[:count]) if limit_reached?
    refuse!(REASONS[:size]) if too_large?
    refuse!(REASONS[:type]) unless allowed_type?

    upload = persist_upload
    ParticipantUploads::ScanJob.perform_later(upload.id)
    upload
  end

  private

  attr_reader :user_session, :question, :params

  def blob
    return @blob if defined?(@blob)

    @blob = ActiveStorage::Blob.find_signed(
      params[:signed_id], purpose: V1::ParticipantUploads::Presign.purpose(user_session, question)
    )
  end

  def uploaded_blob?
    !blob.nil? && blob.attachments.none? && blob.service.exist?(blob.key)
  end

  def limit_reached?
    user_session.participant_uploads.where(question_id: question.id).counts_against_limit.count >=
      Settings.participant_uploads.max_files_per_question
  end

  def too_large?
    blob.byte_size > Settings.participant_uploads.max_size_mb.megabytes
  end

  def allowed_type?
    detected_content_type.in?(Settings.participant_uploads.allowed_content_types)
  end

  def detected_content_type
    @detected_content_type ||= V1::ParticipantUploads::ContentTypeDetector.call(
      V1::ParticipantUploads::BlobRangeIo.new(blob)
    )
  end

  def persist_upload
    ActiveRecord::Base.transaction do
      user_session.lock!
      refuse!(REASONS[:count]) if limit_reached?
      refuse!(REASONS[:missing]) unless blob.attachments.reload.none?

      upload = build_upload
      upload.save!
      upload
    end
  end

  def build_upload
    blob.content_type = detected_content_type
    blob.identified = true
    blob.analyzed = true
    blob.save!

    upload = user_session.participant_uploads.new(
      question: question,
      original_filename: params[:original_filename],
      description: allowed_description,
      content_type_detected: detected_content_type,
      byte_size: blob.byte_size
    )
    upload.file.attach(blob)
    upload
  end

  def allowed_description
    return nil unless question.settings['show_file_description']

    params[:description].presence
  end

  def refuse!(reason)
    raise ComplexException.new(
      I18n.t('participant_uploads.errors.rejected'),
      { reason: reason },
      :unprocessable_content
    )
  end
end
