# frozen_string_literal: true

class V1::InterventionsController < ApplicationController
  def index
    render json: InterventionSerializer.new(interventions_scope).serialized_json
  end

  def show
    render json: InterventionSerializer.new(intervention_load).serialized_json
  end

  def create
    intervention = current_user.interventions.create!(intervention_params)
    render json: intervention, status: :created
  end

  private

  def interventions_scope
    Intervention.accessible_by(current_ability)
  end

  def intervention_load
    interventions_scope.find(params[:id])
  end

  def intervention_params
    params.require(:intervention).permit(:type, :name, settings: {})
  end
end
