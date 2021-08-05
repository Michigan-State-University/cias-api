# frozen_string_literal: true

class V1::InterventionsController < V1Controller
  include Resource::Clone

  def index
    collection = interventions_scope
    paginated_collection = if start_index.present? && end_index.present?
                             end_index_or_last_index = if end_index >= collection.size
                                                         collection.size - 1
                                                       else
                                                         end_index
                                                       end
                             paginated_collection_ids = collection[start_index..end_index_or_last_index].pluck('id')
                             interventions_scope.indexing(paginated_collection_ids)
                           else
                             collection
                           end

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
    Intervention.includes(:sessions).accessible_by(current_ability).order(created_at: :desc)
  end

  def intervention_load
    Intervention.accessible_by(current_ability).find(params[:id])
  end

  def intervention_params
    params.require(:intervention).permit(:name, :status_event, :shared_to, :organization_id, :google_language_id)
  end

  def start_index
    params.permit(:start_index)[:start_index].to_i
  end

  def end_index
    params.permit(:end_index)[:end_index]&.to_i
  end
end
