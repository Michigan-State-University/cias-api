# frozen_string_literal: true

class V1::InterventionsController < V1Controller
  def index
    render json: serialized_response(interventions_scope)
  end

  def show
    render json: serialized_response(intervention_load)
  end

  def create
    intervention = current_user.interventions.create!(intervention_params)
    render json: serialized_response(intervention), status: :created
  end

  def update
    intervention_load.update!(intervention_params.except(:type))
    invalidate_cache(intervention_load)
    render json: serialized_response(intervention_load)
  end

  private

  def interventions_scope
    Intervention.accessible_by(current_ability)
  end

  def intervention_load
    interventions_scope.find(params[:id])
  end

  def intervention_params
    params.require(:intervention).permit(:type, :name, settings: {}, body: {})
  end
end
