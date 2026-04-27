# frozen_string_literal: true

class V1::Interventions::PredefinedParticipantsController < V1Controller
  before_action :verify_access, except: %i[verify ra_session]
  skip_before_action :authenticate_user!, only: %i[verify]

  def index
    render json: serialized_response(predefined_participants, 'PredefinedParticipant',
                                     params: { ra_user_sessions: ra_user_sessions_for_index })
  end

  def show
    render json: serialized_response(predefined_participant, 'PredefinedParticipant',
                                     params: { ra_user_sessions: ra_user_sessions_for_show })
  end

  def create
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    predefined_user = V1::Intervention::PredefinedParticipants::CreateService.call(intervention_load, predefined_user_parameters)

    render json: serialized_response(predefined_user), status: :created
  end

  def bulk_create
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    participant_params_list = predefined_users_parameters[:participants] || []

    if participant_params_list.empty?
      raise ComplexException.new(
        I18n.t('predefined_participants.bulk_import.empty_participants_error'),
        { errors: [{ code: 'empty_participants' }] },
        :unprocessable_entity
      )
    end

    run_bulk_import_validators(participant_params_list)

    payload_record = BulkImportPayload.create!(
      researcher: current_v1_user,
      intervention: intervention_load,
      payload: build_job_payload(participant_params_list)
    )

    PredefinedParticipants::BulkImportJob.perform_later(payload_record.id)

    head :accepted
  end

  def update
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    predefined_user = V1::Intervention::PredefinedParticipants::UpdateService.call(intervention_load, predefined_participant, predefined_user_parameters)

    render json: serialized_response(predefined_user)
  end

  def verify
    return head :unauthorized if current_v1_user.present? && !current_v1_user.role?('predefined_participant')

    check_intervention_status

    access_token_to_response!
    render json: verify_response
  end

  def destroy
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    predefined_participant.update!(active: false)

    render status: :no_content
  end

  def ra_session
    @predefined_user_parameter = PredefinedUserParameter.find_by!(slug: params[:slug])
    intervention = predefined_user_parameter.intervention
    participant = predefined_user_parameter.user

    authorize! :fulfill_ra_session, intervention
    check_intervention_status

    ra_session = intervention.sessions.find_by!(type: 'Session::ResearchAssistant')

    user_intervention = UserIntervention.find_or_create_by(
      user_id: participant.id,
      intervention_id: intervention.id,
      health_clinic_id: predefined_user_parameter.health_clinic_id
    )

    user_session = UserSession::ResearchAssistant.find_or_create_by(
      session_id: ra_session.id,
      user_id: participant.id,
      type: 'UserSession::ResearchAssistant',
      user_intervention_id: user_intervention.id,
      health_clinic_id: predefined_user_parameter.health_clinic_id
    )

    if user_session.finished_at.present?
      render json: {
        data: {
          user_session_id: user_session.id,
          session_id: ra_session.id,
          intervention_id: intervention.id,
          health_clinic_id: predefined_user_parameter.health_clinic_id,
          lang: intervention.language_code,
          already_completed: true
        }
      }, status: :ok
      return
    end

    user_session.update!(fulfilled_by_id: current_v1_user.id, started: true)
    user_intervention.in_progress! if user_intervention.ready_to_start?

    render json: {
      data: {
        user_session_id: user_session.id,
        session_id: ra_session.id,
        intervention_id: intervention.id,
        health_clinic_id: predefined_user_parameter.health_clinic_id,
        lang: intervention.language_code,
        already_completed: false
      }
    }, status: :ok
  end

  def send_sms_invitation
    V1::Intervention::PredefinedParticipants::SendSmsInvitation.call(predefined_participant)
    render json: predefined_participant.predefined_user_parameter.reload.slice(:sms_invitation_sent_at), status: :ok
  end

  def send_email_invitation
    V1::Intervention::PredefinedParticipants::SendEmailInvitation.call(predefined_participant)
    render json: predefined_participant.predefined_user_parameter.reload.slice(:email_invitation_sent_at), status: :ok
  end

  private

  def access_token_to_response!
    response.headers.merge!(predefined_user_parameter.user.create_new_auth_token)
  end

  def verify_response
    {
      user: V1::UserSerializer.new(predefined_user_parameter.user).serializable_hash[:data],
      redirect_data: V1::Intervention::PredefinedParticipants::VerifyService.call(predefined_user_parameter)
    }
  end

  def predefined_user_parameters
    params.require(:predefined_user).permit(:first_name, :last_name, :health_clinic_id, :active, :auto_invitation, :external_id, :email,
                                            :sms_notification, :email_notification, phone_attributes: %i[iso prefix number])
  end

  def predefined_users_parameters
    params.require(:predefined_users).permit(
      participants: [
        :first_name,
        :last_name,
        :email,
        :external_id,
        :email_notification,
        :sms_notification,
        :health_clinic_id,
        :health_clinic_name,
        :health_system_name,
        { phone_attributes: %i[iso prefix number], variable_answers: {} }
      ]
    )
  end

  def build_job_payload(participant_params_list)
    participant_params_list.map do |params|
      attributes = params.to_h.deep_stringify_keys.except('variable_answers')
      variable_answers = (params[:variable_answers] || {}).to_h.deep_stringify_keys
      { 'attributes' => attributes, 'variable_answers' => variable_answers }
    end
  end

  # Run both validators and accumulate errors so the researcher sees every issue in one response,
  # not just the first one. Each validator's `.call` raises ComplexException with `{ errors: [...] }`;
  # we catch, concat, and raise once at the end. The two error sets share the `{ row:, field:, code: }`
  # shape and `field` is naturally namespaced (`email`/`phone.*`/`health_clinic_id` vs `<sess>.<var>`),
  # so the frontend can route each entry to the correct CSV cell unambiguously.
  def run_bulk_import_validators(participant_params_list)
    errors = []

    [
      -> { V1::Intervention::PredefinedParticipants::ParticipantAttributesValidator.call(participant_params_list) },
      -> { V1::Intervention::PredefinedParticipants::VariableAnswersValidator.call(intervention_load, participant_params_list) }
    ].each do |validator|
      validator.call
    rescue ComplexException => e
      errors.concat(e.additional_information[:errors])
    end

    return if errors.empty?

    raise ComplexException.new(
      I18n.t('predefined_participants.bulk_import.bulk_import_validation_error'),
      { errors: errors },
      :unprocessable_entity
    )
  end

  def intervention_load
    @intervention_load ||= Intervention.accessible_by(current_ability).find(intervention_id)
  end

  def predefined_participants
    @predefined_participants ||= intervention_load.predefined_users.includes(:predefined_user_parameter, :phone)
  end

  def predefined_participant
    @predefined_participant ||= predefined_participants.find(params[:id])
  end

  def predefined_user_parameter
    @predefined_user_parameter ||= PredefinedUserParameter.find_by!(slug: slug)
  end

  def intervention_id
    params[:intervention_id]
  end

  def slug
    params[:slug]
  end

  def ra_user_sessions_for_index
    ra_session = intervention_load.sessions.find_by(type: 'Session::ResearchAssistant')
    return {} if ra_session.nil?

    UserSession.where(session_id: ra_session.id, user_id: predefined_participants.map(&:id))
               .includes(:fulfilled_by)
               .index_by(&:user_id)
  end

  def ra_user_sessions_for_show
    ra_session = intervention_load.sessions.find_by(type: 'Session::ResearchAssistant')
    return {} if ra_session.nil?

    ra_user_session = UserSession.includes(:fulfilled_by)
                                 .find_by(session_id: ra_session.id, user_id: predefined_participant.id)
    return {} if ra_user_session.nil?

    { predefined_participant.id => ra_user_session }
  end

  def verify_access
    authorize! :update, Intervention
    authorize! :update, intervention_load
  end

  def check_intervention_status
    intervention = predefined_user_parameter.intervention
    return if intervention.published?

    raise ComplexException.new(I18n.t('short_link.error.not_available'), { reason: 'INTERVENTION_DRAFT' }, :bad_request) if intervention.draft?

    raise ComplexException.new(I18n.t('short_link.error.not_available'), { reason: 'INTERVENTION_PAUSED' }, :bad_request) if intervention.paused?

    raise ComplexException.new(I18n.t('short_link.error.not_available'), { reason: 'INTERVENTION_CLOSED' }, :bad_request)
  end
end
