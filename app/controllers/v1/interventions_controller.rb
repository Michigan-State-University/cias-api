# frozen_string_literal: true

class V1::InterventionsController < V1Controller
  include Resource::Clone
  include Resource::Position
  skip_before_action :authenticate_v1_user!, on: :index, if: -> { params[:allow_guests] }

  def index
    if params[:allow_guests]
      render json: serialized_response(Intervention.published.allow_guests)
    else
      render json: serialized_response(interventions_scope)
    end
  end

  def show
    render json: serialized_response(intervention_load)
  end

  def create
    intervention = interventions_scope.create!(intervention_params)
    render json: serialized_response(intervention), status: :created
  end

  def update
    intervention = intervention_load
    intervention.assign_attributes(intervention_params)
    intervention.integral_update
    render json: serialized_response(intervention)
  end

  private

  def interventions_scope
    Problem.includes(:interventions).accessible_by(current_ability).find(params[:problem_id]).interventions
  end

  def intervention_load
    interventions_scope.find(params[:id])
  end

  def intervention_params
    params.require(:intervention).permit(:status_event, :allow_guests, :name, :position, :problem_id, narrator: {}, settings: {}, formula: {}, body: {})
  end
end
