# frozen_string_literal: true

class V1::Interventions::PredefinedParticipantsController < V1Controller
  before_action :verify_access, except: [:verify]
  skip_before_action :authenticate_user!, only: %i[verify]

  def index
    render json: serialized_response(predefined_participants)
  end

  def show
    render json: serialized_response(predefined_participant)
  end

  def create
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    predefined_user = V1::Intervention::PredefinedParticipants::CreateService.call(intervention_load, predefined_user_parameters)

    render json: serialized_response(predefined_user), status: :created
  end

  def bulk_create
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    predefined_users = V1::Intervention::PredefinedParticipants::BulkCreateService.call(intervention_load, predefined_users_parameters)

    render json: serialized_response(predefined_users), status: :created
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
      :intervention_id,
      participants: [
        :first_name,
        :last_name,
        :email,
        :external_id,
        :email_notification,
        :sms_notification,
        { phone: %i[iso number] }
      ]
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
