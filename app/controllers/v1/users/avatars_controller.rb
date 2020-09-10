# frozen_string_literal: true

class V1::Users::AvatarsController < V1Controller
  def create
    authorize! :update, user_load

    user_load.update!(avatar: avatar_params[:file])
    invalidate_cache(user_load)
    render json: serialized_response(user_load, 'User'), status: 201
  end

  def destroy
    authorize! :update, user_load

    user_load.avatar.purge
    invalidate_cache(user_load)
    render json: serialized_response(user_load, 'User')
  end

  private

  def user_load
    User.accessible_by(current_ability).find(params[:user_id])
  end

  def avatar_params
    params.require(:avatar).permit(:file)
  end
end
