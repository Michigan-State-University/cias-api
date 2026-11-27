# frozen_string_literal: true

module ActiveStorage::ParticipantUploadGuard
  def self.prepended(base)
    # Callback, not an overridden `show`: `set_representation` would already have fed
    # the file to image processing, possibly before the scanner's verdict.
    base.prepend_before_action :refuse_participant_upload
  end

  private

  def refuse_participant_upload
    head :not_found if participant_upload_blob?
  end

  def participant_upload_blob?
    signed_id = params[:signed_blob_id] || params[:signed_id]
    blob = ActiveStorage::Blob.find_signed(signed_id)
    return false if blob.nil?

    ActiveStorage::Attachment.exists?(blob_id: blob.id, record_type: 'ParticipantUpload')
  end
end
