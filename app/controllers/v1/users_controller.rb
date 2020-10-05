# frozen_string_literal: true

class V1::UsersController < V1Controller
  def index
    collection = users_scope.detailed_search(params).order(created_at: :desc)
    paginated_collection = paginate(collection, params)
    render_json users: paginated_collection
  end

  def show
    render_json user: user_load
  end

  def update
    authorize_update_abilities

    user_load.update!(user_params)
    invalidate_cache(user_load)
    render_json user: user_load, action: :show
  end

  def destroy
    user_load.deactivate!
    head :no_content
  end

  private

  def users_scope
    User.includes(:address).accessible_by(current_ability)
  end

  def user_load
    users_scope.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :phone, :time_zone, :active, roles: [], address_attributes: %i[name country state state_abbreviation city zip_code street building_address apartment_number])
  end

  def authorize_update_abilities
    authorize! :update, user_load
    %i[active roles].each do |attr|
      authorize! :update, attr unless user_params[attr].nil?
    end
  end
end
