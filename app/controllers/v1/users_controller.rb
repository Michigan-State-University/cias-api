# frozen_string_literal: true

class V1::UsersController < V1Controller
  skip_before_action :authenticate_user!, only: %i[confirm_logging_code]

  def index
    authorize! :index, current_v1_user

    collection = users_scope.detailed_search(params.merge(user_roles: current_v1_user.roles, organization_id: current_v1_user.organizable&.id)).order(created_at: :desc)
    paginated_collection = paginate(collection, params)
    render_json users: paginated_collection, users_size: collection.size, query_string: query_string_digest
  end

  def show
    render json: serialized_response(user_service.user_load(user_id))
  end

  def researchers
    authorize! :list_researchers, User

    collection = UserFinder.available_researchers(current_v1_user)
    paginated_collection = paginate(collection, params)
    render_json users: paginated_collection, users_size: collection.size, query_string: query_string_digest
  end

  def update
    authorize_update_abilities

    user = user_service.user_load(user_id)
    user.update!(user_params)

    render json: serialized_response(user)
  end

  def destroy
    user_service.user_load(user_id).deactivate!
    head :no_content
  end

  def send_sms_token
    authorize! :update, current_v1_user

    phone = phone_service.get_phone
    head :expectation_failed and return unless phone

    phone.refresh_confirmation_code
    number = phone.prefix + phone.number
    sms = Message.create(
      phone: number,
      body: "Your CIAS verification code is: #{phone.confirmation_code}"
    )
    service = Communication::Sms.new(sms.id)
    service.send_message
    head service.errors.empty? ? :accepted : :expectation_failed
  end

  def verify_sms_token
    phone = current_v1_user.phone
    head :expectation_failed and return unless phone&.token_correct?(params[:sms_token])

    phone.confirm!
    head :ok
  end

  def confirm_logging_code
    result = V1::Users::Verifications::Confirm.call(code, email)
    if result.present?
      render json: { verification_code: result }, status: :ok
    else
      head :request_timeout
    end
  end

  private

  def user_service
    @user_service ||= V1::UserService.new(current_v1_user)
  end

  def phone_service
    @phone_service ||= V1::Users::PhoneService.new(current_v1_user, phone_params)
  end

  def users_scope
    user_service.users_scope.includes(:team, :phone, :avatar_attachment)
  end

  def user_id
    params[:id]
  end

  def code
    params[:verification_code]
  end

  def email
    params[:email]
  end

  def phone_params
    params.permit(:phone_number, :iso, :prefix)
  end

  def user_params
    if (current_v1_user.roles & %w[team_admin researcher]).present? && current_v1_user.id != user_id
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

  def query_string_digest
    Digest::SHA1.hexdigest("#{params[:page]}#{params[:per_page]}#{params[:name]}#{params[:roles]&.join}#{params[:active]}")
  end

  def authorize_update_abilities
    user = user_service.user_load(user_id)
    authorize! :update, user
    %i[active roles].each do |attr|
      authorize! attr, user unless user_params[attr].nil?
    end
  end
end
