# frozen_string_literal: true

class V1::Organizations::Sessions::InvitationsController < V1Controller
  def index
    authorize! :read, Invitation
    grouped_invitations = session_invitations_scope.group_by(&:health_clinic_id)
    render json: grouped_invitations, each_serializer: V1::InvitationSerializer
  end

  def create
    return head :not_acceptable unless session_load.published?

    authorize! :create, Invitation
    targets.each do |target|
      session_load.invite_by_email(target[:emails], target[:health_clinic_id])
    end

    grouped_invitations = session_invitations_scope.group_by(&:health_clinic_id)
    render json: grouped_invitations, each_serializer: V1::InvitationSerializer, status: :created
  end

  def destroy
    session_invitations_load.destroy!
    head :no_content
  end

  def resend
    head session_invitations_load.resend
  end

  private

  def session_load
    Session.accessible_by(current_ability).find(params[:session_id])
  end

  def session_invitations_scope
    session_load.invitations
  end

  def session_invitations_load
    session_invitation_scope.find(params[:id])
  end

  def session_invitations_params
    params.permit(
      session_invitations: [
        :health_clinic_id,
        { emails: [] }
      ]
    )
  end

  def targets
    session_invitations_params[:session_invitations]
  end
end
