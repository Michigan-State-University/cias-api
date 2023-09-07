# frozen_string_literal: true

# frozen_string_require: true

class V1::Interventions::PredefinedParticipantsController < V1Controller
  def show
    authorize! :read, Intervention
    authorize! :read, intervention_load

    render json: serialized_response(predefined_participant)
  end

  def index
    authorize! :read, Intervention
    authorize! :read, intervention_load

    render json: serialized_response(predefined_participants)
  end

  def create
    authorize! :update, Intervention
    authorize! :update, intervention_load
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    predefined_user = V1::Intervention::PredefinedParticipants::CreateService.call(intervention_load, predefined_user_parameters)

    render json: serialized_response(predefined_user), status: :created
  end

  def update
    authorize! :update, Intervention
    authorize! :update, intervention_load
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    predefined_user = V1::Intervention::PredefinedParticipants::UpdateService.call(intervention_load, predefined_participant, predefined_user_parameters)

    render json: serialized_response(predefined_user)
  end

  def destroy
    authorize! :read, Intervention
    authorize! :read, intervention_load
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    V1::Intervention::PredefinedParticipants::UpdateService.call(intervention_load, predefined_participant, { active: false })

    render status: :no_content
  end

  private

  def predefined_user_parameters
    params.require(:predefined_user).permit(:first_name, :last_name, :health_clinic_id, :active, phone_attributes: %i[iso prefix number])
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
end
