# frozen_string_literal: true

class V1::PreviewSessionUsersController < V1Controller
  def create
    authorize! :create, :preview_session_user

    user = create_preview_session_user(session_id)
    render json: user.create_new_auth_token
  end

  private

  def session_id
    params.require(:session_id)
  end
end
