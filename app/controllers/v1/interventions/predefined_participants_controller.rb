# frozen_string_literal: true

# frozen_string_require: true

class V1::Interventions::PredefinedParticipantsController < V1Controller
  before_action :verify_access

  def show
    render json: serialized_response(predefined_participant)
  end

  def index
    render json: serialized_response(predefined_participants)
  end

  def create
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    predefined_user = V1::Intervention::PredefinedParticipants::CreateService.call(intervention_load, predefined_user_parameters)

    render json: serialized_response(predefined_user), status: :created
  end

  def update
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    predefined_user = V1::Intervention::PredefinedParticipants::UpdateService.call(intervention_load, predefined_participant, predefined_user_parameters)

    render json: serialized_response(predefined_user)
  end

  def send_invitation
    V1::Intervention::PredefinedParticipants::SendInvitation.call(predefined_participant)
    render json: predefined_participant.predefined_user_parameter.reload.slice(:invitation_sent_at), status: :ok
  end

  private

  def predefined_user_parameters
    params.require(:predefined_user).permit(:first_name, :last_name, :health_clinic_id, :auto_invitation, phone_attributes: %i[iso prefix number])
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

  def intervention_id
    params[:intervention_id]
  end

  def verify_access
    authorize! :update, Intervention
    authorize! :update, intervention_load
  end
end
