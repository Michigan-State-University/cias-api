# frozen_string_literal: true

class V1::UserSessionsController < V1Controller

  def create
    user_session = user_session_service.create(user_session_params)
    render json: serialized_response(user_session), status: :ok
  end

  private

  def user_session_service
    @user_session_service ||= V1::UserSessionService.new(current_v1_user)
  end

  def user_session_params
    params.require(:user_session).permit(:session_id)
  end
end
