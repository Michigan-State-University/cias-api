# frozen_string_literal: true

class V1::PreviewSessionUsersController < V1Controller
  def create
    authorize! :create, :preview_session_user
    return render json: { message: I18n.t('users.preview.cat_mh') }, status: :method_not_allowed if cat_session_preview?

    user = create_preview_session_user(session_id)
    render json: user.create_new_auth_token
  end

  private

  def session_id
    params.require(:session_id)
  end

  def cat_session_preview?
    Session.find(session_id).type.eql? 'Session::CatMh'
  end
end
