# frozen_string_literal: true

class V1::Interventions::StarsController < V1Controller
  def create
    authorize! :read, Intervention

    current_v1_user.stars.find_or_create_by(intervention_id: intervention_load.id)

    render json: serialized_response(intervention_load, 'Intervention', params: { current_user_id: current_v1_user.id })
  end

  def destroy
    authorize! :read, Intervention

    current_v1_user.stars.delete_by(intervention_id: intervention_load.id)

    render json: serialized_response(intervention_load, 'Intervention', params: { current_user_id: current_v1_user.id })
  end

  private

  def interventions_scope
    @interventions_scope ||= Intervention.accessible_by(current_ability)
                                         .order(created_at: :desc)
  end

  def intervention_load
    @intervention_load ||= interventions_scope.find(params[:intervention_id])
  end
end
