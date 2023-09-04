# frozen_string_literal: true

# frozen_string_require: true

class V1::Interventions::PredefinedParticipantsController < V1Controller
  def show; end

  def index; end

  def create
    authorize! :update, Intervention
    authorize! :update, intervention_load

    predefined_user = V1::Intervention::PredefinedParticipants::CreateService.call(intervention_load, predefined_user_parameters)

    render json: serialized_response(predefined_user), status: :created
  end

  def destroy; end

  private

  def intervention_load
    @intervention_load ||= Intervention.accessible_by(current_ability).find(intervention_id)
  end

  def predefined_user_parameters
    params.require(:predefined_user).permit(:first_name, :last_name, :health_clinic_id, phone_attributes: %i[iso prefix number])
  end

  def intervention_id
    params[:intervention_id]
  end
end
