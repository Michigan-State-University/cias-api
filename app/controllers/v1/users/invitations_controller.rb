# frozen_string_literal: true

class V1::Users::InvitationsController < V1Controller
  skip_before_action :authenticate_user!, only: %i[edit update]

  def index
    render json: serialized_response(researchers_not_accepted_invitations, 'User', { only_email: true })
  end

  def create
    authorize! :create, User

    user = V1::Users::Invitations::Create.call(invited_email)

    return render json: { error: I18n.t('devise.failure.email_already_exists') }, status: :unprocessable_entity unless user

    if user.valid?
      render json: serialized_response(user, 'User', { only_email: true }), status: :created
    else
      render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def resend
    authorize! :create, User

    user = user_load
    user = User.invite!(email: user.email, roles: user.roles)

    if user.valid?
      render json: serialized_response(user, controller_name.classify, { only_email: true })
    else
      render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  # This endpoint will be hit from mailer link, thus it needs to be public
  def edit
    user = User.where.not(invitation_token: nil).find_by_invitation_token(invitation_token, true) # rubocop:disable Rails/DynamicFindBy

    # Unfortunetly find_by_invitation_token method doesn't raise exception when there is no user
    # and there is no version with !
    return redirect_to_web_app(error: I18n.t('users.invite.not_active')) if user.blank?

    redirect_to "#{ENV['WEB_URL']}/register?invitation_token=#{invitation_token}&email=#{user.email}&role=#{user.roles.first}"
  end

  # This endpoint is hit from registration page to register new user from invitation
  # link, thus there is no need for authorization
  def update
    user = V1::Users::Invitations::Update.call(accept_invitation_params)

    if user.persisted?
      prepare_registration_data(user)
      render json: serialized_hash(user, 'User', { only_email: true }).merge({ verification_code: user_verification_code(user) })
    else
      render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy
    user_load.destroy!

    head :no_content
  end

  private

  def users_scope
    User.accessible_by(current_ability)
  end

  def user_load
    users_scope.find(params[:id])
  end

  def researchers_not_accepted_invitations
    users_scope.invitation_not_accepted.limit_to_roles(['researcher'])
  end

  def accept_invitation_params
    params.require(:invitation).permit(:invitation_token, :password, :password_confirmation, :first_name, :last_name,
                                       :time_zone)
  end

  def invited_email
    params.require(:invitation).permit(:email)[:email]
  end

  def invitation_token
    params[:invitation_token]
  end

  def redirect_to_web_app(**message)
    message.transform_values! { |v| Base64.encode64(v) }

    redirect_to "#{ENV['WEB_URL']}?#{message.to_query}"
  end

  def user_verification_code(user)
    user.user_verification_codes.where(confirmed: false).order(created_at: :desc).first&.code
  end

  # rubocop:disable Naming/AccessorMethodName
  def set_devise_headers(user)
    response.headers.merge!(user.create_new_auth_token)
  end
  # rubocop:enable Naming/AccessorMethodName

  def prepare_registration_data(user)
    set_devise_headers(user)
    user.user_verification_codes.create!(code: SecureRandom.base64(6))
  end
end
