# frozen_string_literal: true

class V1::InterventionsController < V1Controller
  include Resource::Clone

  def index
    render json: serialized_response(interventions_scope)
  end

  def show
    render json: serialized_response(intervention_load)
  end

  def create
    authorize! :create, Intervention

    intervention = current_v1_user.interventions.create!(intervention_params)
    render json: serialized_response(intervention), status: :created
  end

  def update
    authorize! :update, Intervention

    intervention = intervention_load
    intervention.assign_attributes(intervention_params)
    intervention.save!
    render json: serialized_response(intervention)
  end

  private

  def interventions_scope
    Intervention.without_organization.includes(:sessions).accessible_by(current_ability).order(created_at: :desc)
  end

  def intervention_load
    Intervention.accessible_by(current_ability).find(params[:id])
  end

  def intervention_params
    params.require(:intervention).permit(:name, :status, :shared_to, :organization_id, :google_language_id)
  end
end
