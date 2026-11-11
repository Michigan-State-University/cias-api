# frozen_string_literal: true

class V1::Interventions::PredefinedParticipantsController < V1Controller
  include ::PredefinedParticipants::InterventionGate

  before_action :verify_access, except: %i[verify ra_session]
  before_action :require_current_editor, except: %i[index show verify ra_session]
  skip_before_action :authenticate_user!, only: %i[verify]

  def index
    render json: serialized_response(predefined_participants, 'PredefinedParticipant',
                                     params: { ra_user_sessions: ra_user_sessions(predefined_participants.map(&:id)) })
  end

  def show
    render json: serialized_response(predefined_participant, 'PredefinedParticipant',
                                     params: { ra_user_sessions: ra_user_sessions([predefined_participant.id]) })
  end

  def create
    predefined_user = V1::Intervention::PredefinedParticipants::CreateService.call(intervention_load, predefined_user_parameters)

    render json: serialized_response(predefined_user), status: :created
  end

  def bulk_create
    participant_params_list = predefined_users_parameters[:participants] || []

    if participant_params_list.empty?
      raise ComplexException.new(
        I18n.t('predefined_participants.bulk_import.empty_participants_error'),
        { errors: [{ code: 'empty_participants' }] },
        :unprocessable_content
      )
    end

    if any_variable_answers_present?(participant_params_list) && !intervention_load.published?
      raise ComplexException.new(
        I18n.t('predefined_participants.bulk_import.ra_answers_require_published_intervention_error'),
        { errors: [{ code: 'ra_answers_require_published_intervention_error' }] },
        :unprocessable_content
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
    predefined_participant.update!(active: false)

    render status: :no_content
  end

  def ra_session
    intervention = predefined_user_parameter.intervention

    authorize! :fulfill_ra_session, intervention
    check_intervention_status

    result = V1::Intervention::PredefinedParticipants::FulfillRaSessionService.call(
      intervention: intervention,
      participant: predefined_user_parameter.user,
      fulfilled_by: current_v1_user,
      health_clinic_id: predefined_user_parameter.health_clinic_id
    )

    render json: { data: ra_session_payload(intervention, result) }, status: :ok
  end

  def send_sms_invitation
    V1::PredefinedParticipants::ResendService.call(predefined_participant,
                                                   intervention: intervention_load,
                                                   min_interval: resend_min_interval)
    render json: predefined_participant.predefined_user_parameter.reload.slice(:sms_invitation_sent_at), status: :ok
  end

  def send_email_invitation
    V1::Intervention::PredefinedParticipants::SendEmailInvitation.call(predefined_participant)
    render json: predefined_participant.predefined_user_parameter.reload.slice(:email_invitation_sent_at), status: :ok
  end

  private

  def resend_min_interval
    Settings.sms_campaigns.resend_min_interval_minutes.minutes
  end

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
    params.expect(predefined_user: [:first_name, :last_name, :health_clinic_id, :active, :auto_invitation, :external_id, :email,
                                    :sms_notification, :email_notification, { phone_attributes: %i[iso prefix number] }])
  end

  def predefined_users_parameters
    params.expect(
      predefined_users: [participants: [[
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
      ]]]
    )
  end

  def build_job_payload(participant_params_list)
    participant_params_list.map do |params|
      attributes = params.to_h.deep_stringify_keys.except('variable_answers')
      variable_answers = (params[:variable_answers] || {}).to_h.deep_stringify_keys
      { 'attributes' => attributes, 'variable_answers' => variable_answers }
    end
  end

  def any_variable_answers_present?(participant_params_list)
    participant_params_list.any? { |p| p[:variable_answers].present? }
  end

  # Run both validators and accumulate errors so the researcher sees every issue in one response
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
      :unprocessable_content
    )
  end

  def predefined_participants
    @predefined_participants ||= intervention_load.predefined_users.includes(:predefined_user_parameter, :phone)
  end

  def predefined_participant
    @predefined_participant ||= intervention_load.predefined_users.find(params[:id])
  end

  def predefined_user_parameter
    @predefined_user_parameter ||= PredefinedUserParameter.find_by!(slug: slug)
  end

  def slug
    params[:slug]
  end

  def ra_user_sessions(user_ids)
    V1::Intervention::PredefinedParticipants::RaUserSessionsService.call(intervention_load, user_ids)
  end

  def ra_session_payload(intervention, result)
    {
      user_session_id: result.user_session.id,
      session_id: result.user_session.session_id,
      intervention_id: intervention.id,
      health_clinic_id: predefined_user_parameter.health_clinic_id,
      lang: intervention.language_code,
      already_completed: result.already_completed
    }
  end

  def check_intervention_status
    intervention = predefined_user_parameter.intervention
    return if intervention.published?

    raise ComplexException.new(I18n.t('short_link.error.not_available'), { reason: 'INTERVENTION_DRAFT' }, :bad_request) if intervention.draft?

    raise ComplexException.new(I18n.t('short_link.error.not_available'), { reason: 'INTERVENTION_PAUSED' }, :bad_request) if intervention.paused?

    raise ComplexException.new(I18n.t('short_link.error.not_available'), { reason: 'INTERVENTION_CLOSED' }, :bad_request)
  end
end
