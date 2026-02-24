# frozen_string_literal: true

class V1::UserInterventionsController < V1Controller
  before_action :validate_intervention_status, only: %i[create]
  skip_before_action :authenticate_user!, only: %i[create]
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
    user_intervention = UserIntervention.find_or_initialize_by(
      user_id: user_id,
      intervention_id: intervention_id,
      health_clinic_id: health_clinic_id
    )

    authorize! :create, user_intervention

    user_intervention.in_progress!
    user_intervention.save!

    @current_v1_user_or_guest_user.update!(quick_exit_enabled: intervention.quick_exit, language_code: user_intervention.intervention.language_code)

    render json: serialized_response(user_intervention)
  end

  private

  def current_v1_user_or_guest_user
    @current_v1_user_or_guest_user ||= current_v1_user || create_guest_user
  end

  def create_guest_user
    user = V1::Users::CreateGuest.call
    response.headers.merge!(user.create_new_auth_token)
    user
  end

  def user_id
    current_v1_user_or_guest_user.id
  end

  def current_ability
    current_v1_user_or_guest_user.ability
  end

  def user_intervention_load
    user_intervention_scope.find(params[:id])
  end

  def intervention
    Intervention.find(intervention_id)
  end

  def user_intervention_scope
    UserIntervention.includes(:user, intervention: [:intervention_accesses, { files_attachments: :blob }])
                    .accessible_by(current_ability)
                    .order(created_at: :desc)
                    .where(intervention: { status: %w[published paused] })
  end

  def user_intervention_extended_scope
    UserIntervention.includes(:user, :user_sessions,
                              intervention: [{ sessions: %i[sms_codes google_language] }, :intervention_accesses, { files_attachments: :blob }])
                    .accessible_by(current_ability)
                    .order(created_at: :desc)
                    .where(intervention: { status: %w[published paused] })
  end

  def user_intervention_params
    params.expect(user_intervention: %i[intervention_id health_clinic_id])
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
