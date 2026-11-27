# frozen_string_literal: true

class V1::ParticipantUploadsController < V1Controller
  include ActiveStorage::Streaming

  def file
    authorize! :get_protected_attachment, intervention_load

    return removed_response if upload_load.removed_by_scanner?
    return pending_response unless upload_load.servable?

    send_blob_stream(upload_load.file.blob, disposition: disposition)
  end

  def show
    authorize! :get_protected_attachment, intervention_load

    render json: serialized_response(upload_load, 'ParticipantUpload', params: { show_moderation: true })
  end

  # Not named `config`: that shadows ActionController#config and recurses.
  def upload_config
    authorize! :read_upload_config, ParticipantUpload

    render json: {
      allowed_content_types: Settings.participant_uploads.allowed_content_types,
      accepted_extensions: Settings.participant_uploads.accepted_extensions,
      inline_preview_content_types: Settings.participant_uploads.inline_preview_content_types,
      max_size_bytes: Settings.participant_uploads.max_size_mb.megabytes,
      max_files_per_question: Settings.participant_uploads.max_files_per_question
    }
  end

  private

  def upload_load
    @upload_load ||= ParticipantUpload.find(params[:id])
  end

  def intervention_load
    @intervention_load ||= upload_load.user_session.session.intervention
  end

  def disposition
    upload_load.served_inline? ? 'inline' : 'attachment'
  end

  def pending_response
    raise ComplexException.new(
      I18n.t('participant_uploads.errors.pending_scan'),
      { reason: 'FILE_PENDING_SCAN' },
      :unprocessable_content
    )
  end

  def removed_response
    raise ComplexException.new(
      I18n.t('participant_uploads.errors.removed_by_scanner'),
      { reason: 'FILE_REMOVED_BY_SECURITY_SCAN',
        deletion_reason: upload_load.deletion_reason,
        deleted_at: upload_load.deleted_at },
      :gone
    )
  end
end
