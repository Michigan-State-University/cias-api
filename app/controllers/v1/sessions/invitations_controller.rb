# frozen_string_literal: true

# Controller returns all address emails who have been invited to a particular session;
# Invite does not mean grant access;
# Invites is a feature to inform and create an account based on provided email if it didn't exist in the system;
# Granted access is kept in UserSession;
# Check also Intervention::StatusKeeper::Broadcast.
class V1::Sessions::InvitationsController < V1Controller
  def index
    render_json session_invitations: session_invitations_scope
  end

  def create
    authorize! :create, SessionInvitation

    session_load.invite_by_email(session_invitation_params[:emails])
    render_json session_invitations: session_invitations_scope, action: :index, status: :created
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
    session_load.session_invitations
  end

  def session_invitation_load
    session_invitations_scope.find(params[:id])
  end

  def session_invitation_params
    params.require(:session_invitation).permit(emails: [])
  end
end
