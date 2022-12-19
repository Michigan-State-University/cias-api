# frozen_string_literal: true

class V1::UserInterventionsController < V1Controller
  def index
    collection = user_intervention_scope
    paginated_collection = V1::Paginate.call(collection, start_index, end_index)

    render json: serialized_hash(paginated_collection, controller_name.classify, { params: { exclude: %i[sessions] } }).
      merge({ user_interventions_size: collection.size }).to_json
  end

  def show
    render json: serialized_response(user_intervention_load)
  end

  def create
    authorize! :create, UserIntervention

    user_intervention = UserIntervention.find_or_create_by(
      user_id: current_v1_user.id,
      intervention_id: intervention_id,
      health_clinic_id: health_clinic_id
    )

    current_v1_user.update!(quick_exit_enabled: intervention_load.quick_exit)

    render json: serialized_response(user_intervention)
  end

  private

  def user_intervention_load
    user_intervention_scope.find(params[:id])
  end

  def intervention_load
    Intervention.find(intervention_id)
  end

  def user_intervention_scope
    UserIntervention.joins(:intervention)
                    .accessible_by(current_ability)
                    .order(created_at: :desc)
                    .where(intervention: { status: 'published' })
  end

  def user_intervention_params
    params.require(:user_intervention).permit(:intervention_id, :health_clinic_id)
  end

  def intervention_id
    user_intervention_params[:intervention_id]
  end

  def health_clinic_id
    user_intervention_params[:health_clinic_id]
  end

  def start_index
    params.permit(:start_index)[:start_index]&.to_i
  end

  def end_index
    params.permit(:end_index)[:end_index]&.to_i
  end
end
