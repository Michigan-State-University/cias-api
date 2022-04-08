# frozen_string_literal: true

class V1::UsersController < V1Controller
  skip_before_action :authenticate_user!, only: %i[confirm_logging_code]

  def index
    authorize! :index, current_v1_user

    collection = users_scope.detailed_search(params.merge(user_roles: current_v1_user.roles)).order(created_at: :desc)
    paginated_collection = paginate(collection, params)
    render json: serialized_hash(paginated_collection).merge({ users_size: collection.size }).to_json
  end

  def show
    render json: serialized_response(user_load)
  end

  def researchers
    authorize! :list_researchers, User

    collection = UserFinder.available_researchers(current_v1_user)
    paginated_collection = paginate(collection, params)
    render json: serialized_hash(paginated_collection).merge({ users_size: collection.size }).to_json
  end

  def update
    authorize_update_abilities

    user = V1::Users::Update.call(user_load, user_params)

    render json: serialized_response(user)
  end

  def destroy
    user_load.deactivate!

    head :no_content
  end

  def send_sms_token
    authorize! :update, current_v1_user

    send_service = V1::Users::SmsTokens::Send.call(current_v1_user, phone_params)

    head send_service&.errors&.empty? ? :accepted : :expectation_failed
  end

  def verify_sms_token
    phone = V1::Users::SmsTokens::Verify.call(current_v1_user, params[:sms_token])

    head phone ? :ok : :expectation_failed
  end

  def confirm_logging_code
    result = V1::Users::Verifications::Confirm.call(verification_code_params, email_params)
    if result.present?
      render json: { verification_code: result }, status: :ok
    else
      head :request_timeout
    end
  end

  def me
    render json: serialized_response(current_v1_user)
  end

  private

  def users_scope
    User.accessible_by(current_v1_user.ability).includes(:team, :phone, :avatar_attachment)
  end

  def user_load
    users_scope.find(params[:id])
  end

  def user_id
    params[:id]
  end

  def verification_code_params
    params[:verification_code]
  end

  def email_params
    params[:email]
  end

  def phone_params
    params.permit(:phone_number, :iso, :prefix)
  end

  def user_params
    if (current_v1_user.roles & %w[researcher team_admin]).present? && current_v1_user.id != user_id
      params.require(:user).permit(
        :active
      )
    else
      params.require(:user).permit(
        :first_name,
        :last_name,
        :email,
        :sms_notification,
        :email_notification,
        :time_zone,
        :active,
        :feedback_completed,
        :description,
        :organizable_id,
        roles: [],
        phone_attributes: %i[iso prefix number]
      )
    end
  end

  def authorize_update_abilities
    user = user_load
    authorize! :update, user
    %i[active roles].each do |attr|
      authorize! attr, user unless user_params[attr].nil?
    end
  end
end
