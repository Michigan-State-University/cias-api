# frozen_string_literal: true

class V1::Organizations::Interventions::InvitationsController < V1Controller
  def create
    return head :not_acceptable unless intervention_load.published?

    authorize! :create, Invitation
    targets&.each do |target|
      intervention_load.invite_by_email(target[:emails], target[:health_clinic_id])
    end

    render json: serialized_response(intervention_invitations_scope), status: :created
  end

  private

  def intervention_load
    Intervention.accessible_by(current_ability).find(params[:intervention_id])
  end

  def intervention_invitations_scope
    intervention_load.invitations
  end

  def intervention_invitations_params
    params.permit(
      intervention_invitations: [
        :health_clinic_id,
        { emails: [] }
      ]
    )
  end

  def targets
    intervention_invitations_params[:intervention_invitations]
  end
end
