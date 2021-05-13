# frozen_string_literal: true

class V1::Sessions::InvitationsController < V1Controller
  def index
    render json: serialized_response(session_invitations_scope)
  end

  def create
    return head :not_acceptable unless session_load.published?

    authorize! :create, Invitation
    session_load.invite_by_email(session_invitation_params[:emails])
    render json: serialized_response(session_invitations_scope), status: :created
  end

  def destroy
    session_invitation_load.destroy!
    head :no_content
  end

  def resend
    head session_invitation_load.resend
  end

  private

  def session_load
    Session.accessible_by(current_ability).find(params[:session_id])
  end

  def session_invitations_scope
    session_load.invitations
  end

  def session_invitation_load
    session_invitations_scope.find(params[:id])
  end

  def session_invitation_params
    params.require(:session_invitation).permit(emails: [])
  end
end
