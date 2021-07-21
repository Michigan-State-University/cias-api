# frozen_string_literal: true

class V1::InterventionsController < V1Controller
  include Resource::Clone

  def index
    collection = interventions_scope
    paginated_collection = paginate(collection, params)
    render_json interventions: paginated_collection, interventions_size: collection.size
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
    intervention.integral_update
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
    params.require(:intervention).permit(:name, :status_event, :shared_to, :organization_id, :google_language_id)
  end
end
