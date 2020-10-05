# frozen_string_literal: true

class V1::Users::InvitationsController < V1Controller
  def index
    users = users_scope.invitation_not_accepted.limit_to_roles(['researcher'])

    render_json users: users, status: :ok
  end

  def create
    authorize! :create, User

    return render json: { error: I18n.t('devise.failure.email_already_exists') }, status: :unprocessable_entity if User.exists?(email: invitation_params[:email])

    user = User.invite!(email: invitation_params[:email], roles: %w[researcher])

    if user.valid?
      render_json user: user, action: :show, status: :created
    else
      render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  # This endpoint will be hit from mailer link, thus it needs to be public
  def edit
    user = User.where.not(invitation_token: nil).find_by_invitation_token(params[:invitation_token], true) # rubocop:disable Rails/DynamicFindBy

    # Unfortunetly find_by_invitation_token method doesn't raise exception when there is no user
    # and there is no version with !
    raise ActiveRecord::RecordNotFound if user.blank?

    redirect_to "#{ENV['WEB_URL']}/register?invitation_token=#{params[:invitation_token]}&email=#{user.email}"
  end

  # This endpoint is hit from registration page to register new user from invitation
  # link, thus there is no need for authorization
  def update
    user = User.accept_invitation!(accept_invitation_params)

    if user.persisted?
      render_json user: user, status: :ok
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

  def invitation_params
    params.require(:invitation).permit(:email)
  end

  def accept_invitation_params
    params.require(:invitation).permit(:invitation_token, :password, :password_confirmation, :first_name, :last_name, :time_zone)
  end
end
