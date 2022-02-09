# frozen_string_literal: true

class V1::InterventionsController < V1Controller
  def index
    collection = interventions_scope.detailed_search(params)
    paginated_collection = V1::Intervention::Paginate.call(collection, start_index, end_index)

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

  def clone
    authorize! :update, Intervention

    CloneJobs::Intervention.perform_later(current_v1_user, params[:id], clone_params)

    render status: :ok
  end

  private

  def interventions_scope
    Intervention.accessible_by(current_ability).order(created_at: :desc)
  end

  def intervention_load
    interventions_scope.find(params[:id])
  end

  def intervention_params
    params.require(:intervention).permit(:name, :status_event, :shared_to, :organization_id, :google_language_id)
  end

  def start_index
    params.permit(:start_index)[:start_index]&.to_i
  end

  def end_index
    params.permit(:end_index)[:end_index]&.to_i
  end

  def clone_params
    key = controller_name.singularize.to_sym
    params.fetch(key, {}).permit(*to_permit[key])
  end

  def to_permit
    @to_permit ||= {
      intervention: [{ user_ids: [] }],
      session: [],
      question: [],
      sms_plan: []
    }
  end
end
