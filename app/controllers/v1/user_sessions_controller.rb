# frozen_string_literal: true

class V1::UserSessionsController < V1Controller
  def create
    user_session = UserSession.find_or_initialize_by(session_id: user_session_params['session_id'], user_id: current_v1_user.id)
    authorize! :create, user_session
    user_session.save!
    render json: serialized_response(user_session), status: :ok
  end

  private

  def user_session_params
    params.require(:user_session).permit(:session_id)
  end
end
