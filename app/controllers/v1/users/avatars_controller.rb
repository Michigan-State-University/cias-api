# frozen_string_literal: true

class V1::Users::AvatarsController < V1Controller
  def create
    authorize_user

    user_load.update!(avatar: avatar_params[:file])
    invalidate_cache(user_load)
    render json: serialized_response(user_load, 'User'), status: 201
  end

  def destroy
    authorize_user

    user_load.avatar.purge
    invalidate_cache(user_load)
    render json: serialized_response(user_load, 'User')
  end

  private

  def authorize_user
    raise CanCan::AccessDenied.new if current_v1_user.role?('researcher') && current_v1_user.id != params[:user_id]

    authorize! :update, user_load
  end

  def user_load
    User.accessible_by(current_ability).find(params[:user_id])
  end

  def avatar_params
    params.require(:avatar).permit(:file)
  end
end
