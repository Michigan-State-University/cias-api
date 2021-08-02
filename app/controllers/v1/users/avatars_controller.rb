# frozen_string_literal: true

class V1::Users::AvatarsController < V1Controller
  def create
    authorize_user

    user = V1::Users::Avatars::Create.call(user_load, avatar_params[:file])
    invalidate_cache(user)

    render json: serialized_response(user, 'User'), status: :created
  end

  def destroy
    authorize_user

    user = V1::Users::Avatars::Destroy.call(user_load)
    invalidate_cache(user)

    render json: serialized_response(user, 'User')
  end

  private

  def authorize_user
    raise CanCan::AccessDenied if current_v1_user.role?('researcher') && current_v1_user.id != params[:user_id]

    authorize! :update, user_load
  end

  def user_load
    User.accessible_by(current_ability).find(params[:user_id])
  end

  def avatar_params
    params.require(:avatar).permit(:file)
  end
end
