# frozen_string_literal: true

class V1::UsersController < V1Controller
  def index
    render json: serialized_response(users_scope)
  end

  def show
    render json: serialized_response(user_load)
  end

  def update
    user_load.update!(user_params)
    invalidate_cache(user_load)
    render json: serialized_response(user_load)
  end

  def destroy
    user_load.destroy
    head :ok
  end

  private

  def users_scope
    User.accessible_by(current_ability)
  end

  def user_load
    users_scope.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :phone, :deactivated, roles: [])
  end
end
