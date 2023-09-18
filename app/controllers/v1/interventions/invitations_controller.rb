# frozen_string_literal: true

# Controller returns all users who have access to all session associated with the intervention
# if intervention is shared to only selected registered participant;
class V1::Interventions::InvitationsController < V1Controller
  def index
    render json: serialized_response(invitation_scope)
  end

  def create
    intervention = intervention_load
    authorize! :update, intervention
    authorize! :create, Invitation
    return head :not_acceptable unless intervention.published?

    V1::Intervention::CreateInvitation.call(intervention, invitation_params[:invitations])
    render json: serialized_response(invitation_scope), status: :created
  end

  def destroy
    return head :not_acceptable if intervention_load.closed? || intervention_load.archived?

    invitation_scope.find(params[:id]).destroy
    head :no_content
  end

  def resend
    head invitation_load.resend
  end

  private

  def intervention_load
    @intervention_load ||= Intervention.accessible_by(current_ability).find(params[:intervention_id])
  end

  def invitation_scope
    Invitation.where(invitable_id: intervention_and_sessions_ids)
  end

  def invitation_load
    invitation_scope.find(params[:id])
  end

  def intervention_and_sessions_ids
    intervention_load.sessions.pluck(:id) << intervention_load.id
  end

  def invitation_params
    params.permit(
      invitations: [
        :health_clinic_id,
        :target_id,
        :target_type,
        { emails: [] }
      ]
    )
  end
end
