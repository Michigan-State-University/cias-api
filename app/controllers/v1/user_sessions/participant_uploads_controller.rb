# frozen_string_literal: true

class V1::UserSessions::ParticipantUploadsController < V1Controller
  include ActiveStorage::SetCurrent

  before_action :validate_intervention_status

  def index
    authorize! :read, ParticipantUpload

    render json: serialized_response(uploads_load)
  end

  def show
    authorize! :read, upload_load

    render json: serialized_response(upload_load)
  end

  def presign
    authorize! :create, new_upload
    refuse_finished_session!

    render json: V1::ParticipantUploads::Presign.call(user_session_load, question_load, presign_params)
  end

  def create
    authorize! :create, new_upload
    refuse_finished_session!

    upload = V1::ParticipantUploads::Create.call(user_session_load, question_load, upload_params)

    render json: serialized_response(upload), status: :created
  end

  def destroy
    authorize! :destroy, upload_load
    refuse_finished_session!
    refuse_removed_upload!

    upload_load.destroy!
    head :no_content
  end

  private

  def new_upload
    @new_upload ||= user_session_load.participant_uploads.new(question: question_load)
  end

  def refuse_finished_session!
    return unless user_session_load.finished_at?

    raise ComplexException.new(
      I18n.t('participant_uploads.errors.session_finished'),
      { reason: 'SESSION_FINISHED' },
      :unprocessable_content
    )
  end

  def refuse_removed_upload!
    return unless upload_load.removed_by_scanner?

    raise ComplexException.new(
      I18n.t('participant_uploads.errors.removed_by_scanner'),
      { reason: 'FILE_REMOVED_BY_SECURITY_SCAN' },
      :unprocessable_content
    )
  end

  def intervention
    @intervention ||= user_session_load.session.intervention
  end

  def uploads_load
    @uploads_load ||= user_session_load.participant_uploads.accessible_by(current_ability).order(:created_at)
  end

  def user_session_load
    @user_session_load ||= UserSession.accessible_by(current_ability).find(params[:user_session_id])
  end

  def question_load
    @question_load ||= Question::FileUpload.joins(:question_group)
                                           .where(question_groups: { session_id: user_session_load.session_id })
                                           .find(params.require(:question_id))
  end

  def upload_load
    @upload_load ||= user_session_load.participant_uploads.find(params[:id])
  end

  def presign_params
    @presign_params ||= params.expect(blob: %i[filename byte_size checksum content_type])
  end

  def upload_params
    @upload_params ||= params.expect(participant_upload: %i[signed_id original_filename description])
  end
end
