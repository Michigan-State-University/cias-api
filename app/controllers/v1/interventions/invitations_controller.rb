# frozen_string_literal: true

# Controller returns all users who have access to all session associated with the intervention
# if intervention is shared to only selected registered participant;
class V1::Interventions::InvitationsController < V1Controller
  def index
    render json: serialized_response(intervention_invitation_scope)
  end

  def create
    intervention = intervention_load
    return head :not_acceptable unless intervention.published?

    if intervention.type.eql? 'Intervention'
      return render json: { message: I18n.t('interventions.invitations.wrong_intervention_type') }, status: :unprocessable_entity
    end

    authorize! :create, Invitation

    intervention.invite_by_email(intervention_invitation_params[:emails], intervention_invitation_params[:health_clinic_id])
    render json: serialized_response(intervention_invitation_scope), status: :created
  end

  def destroy
    return head :not_acceptable if intervention_load.closed? || intervention_load.archived?

    intervention_invitation_scope.find(params[:id]).destroy
    head :no_content
  end

  private

  def intervention_load
    Intervention.accessible_by(current_ability).find(params[:intervention_id])
  end

  def intervention_invitation_scope
    intervention_load.invitations
  end

  def user_session_params
    params.require(:user_session).permit(emails: [])
  end

  def intervention_invitation_params
    params.require(:intervention_invitation).permit(:health_clinic_id, emails: [])
  end
end
