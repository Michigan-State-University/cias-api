# frozen_string_literal: true

class V1::UserSessionsController < V1Controller
  skip_before_action :authenticate_user!

  def create
    return head :forbidden if pool_is_overflow?

    user_session = UserSession.find_or_initialize_by(
      session_id: session_id,
      user_id: user_id,
      health_clinic_id: health_clinic_id,
      type: type
    )
    authorize! :create, user_session
    user_session.save!

    render json: serialized_response(user_session), status: :ok
  end

  private

  def pool_is_overflow?
    intervention = session_load.intervention

    return true if cat_sessions_in_intervention.any? && (intervention.cat_mh_pool.blank? || intervention.cat_mh_pool <= intervention.created_cat_mh_session_count) # rubocop:disable Layout/LineLength

    false
  end

  def current_v1_user_or_guest_user
    @current_v1_user_or_guest_user ||= current_v1_user || create_guest_user
  end

  def current_ability
    current_v1_user_or_guest_user.ability
  end

  def create_guest_user
    user = V1::Users::CreateGuest.call
    response.headers.merge!(user.create_new_auth_token)
    user
  end

  def type
    session_load.user_session_type
  end

  def session_load
    Session.find(session_id)
  end

  def cat_sessions_in_intervention
    session_load.intervention.sessions.where(type: 'Session::CatMh')
  end

  def user_session_params
    params.require(:user_session).permit(:session_id, :health_clinic_id)
  end

  def session_id
    user_session_params[:session_id]
  end

  def health_clinic_id
    user_session_params[:health_clinic_id]
  end

  def user_id
    current_v1_user_or_guest_user.id
  end
end
