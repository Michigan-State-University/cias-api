# frozen_string_literal: true

class V1::Users::InviteController < V1Controller
  def researcher
    authorize! :create, User
    InvitationJob::Researcher.perform_later(invite_params[:emails])
    render json: { message: I18n.t('users.invite.researcher') }
  end

  private

  def invite_params
    params.require(:invite).permit(emails: [])
  end
end
