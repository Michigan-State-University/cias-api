# frozen_string_literal: true

class V1::InterventionsController < V1Controller
  include Resource::Clone

  def index
    collection = interventions_scope.detailed_search(params)
    paginated_collection = V1::Intervention::Paginate.call(collection, start_index, end_index)

    render json: serialized_hash(paginated_collection).merge({ interventions_size: collection.size }).to_json
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
    Intervention.accessible_by(current_ability).order(created_at: :desc)
  end

  def intervention_load
    interventions_scope.find(params[:id])
  end

  def intervention_params
    if params[:id].present? && intervention_load.published?
      params.require(:intervention).permit(:status, :cat_mh_pool, :is_access_revoked)
    else
      params.require(:intervention).permit(:name, :status, :shared_to, :organization_id, :google_language_id, :cat_mh_application_id, :cat_mh_organization_id,
                                           :cat_mh_pool, :is_access_revoked, :license_type)
    end
  end

  def start_index
    params.permit(:start_index)[:start_index]&.to_i
  end

  def end_index
    params.permit(:end_index)[:end_index]&.to_i
  end
end
