# frozen_string_literal: true

class V1::UserSessionsController < V1Controller
  skip_before_action :authenticate_user!

  def create
    user_session = UserSession.find_or_initialize_by(session_id: session_id, user_id: user_id, health_clinic_id: health_clinic_id)
    authorize! :create, user_session
    user_session.save!
    render json: serialized_response(user_session), status: :ok
  end

  private

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
