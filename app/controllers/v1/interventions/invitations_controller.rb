# frozen_string_literal: true

# Controller returns all address emails who have been invited to a particular intervention;
# Invite does not mean grant access;
# Invites is a feature to inform and create an account based on provided email if it didn't exist in the system;
# Granted access is kept in UserIntervention;
# Check also Problem::StatusKeeper::Broadcast.
class V1::Interventions::InvitationsController < V1Controller
  def index
    render_json inter_invitations: intervention_invitations_scope
  end

  def create
    authorize! :create, InterventionInvitation

    intervention_load.invite_by_email(intervention_invitation_params[:emails])
    render_json inter_invitations: intervention_invitations_scope, action: :index, status: :created
  end

  def destroy
    intervention_invitation_load.destroy!
    head :no_content
  end

  def resend
    head intervention_invitation_load.resend
  end

  private

  def intervention_load
    Intervention.accessible_by(current_ability).find(params[:intervention_id])
  end

  def intervention_invitations_scope
    intervention_load.intervention_invitations
  end

  def intervention_invitation_load
    intervention_invitations_scope.find(params[:id])
  end

  def intervention_invitation_params
    params.require(:intervention_invitation).permit(emails: [])
  end
end
