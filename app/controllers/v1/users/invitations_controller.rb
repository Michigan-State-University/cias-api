# frozen_string_literal: true

class V1::Users::InvitationsController < V1Controller
  def index
    users = users_scope.invitation_not_accepted.limit_to_roles(['researcher'])

    render_json users: users, status: :ok
  end

  def create
    authorize! :create, User

    user = User.invite!(email: invitation_params[:email], roles: %w[researcher])

    if user.valid?
      render_json user: user, action: :show, status: :created
    else
      render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy
    user_load.update!(invitation_token: nil)
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
end
