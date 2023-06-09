# frozen_string_literal: true

class V1::Organizations::Sessions::InvitationsController < V1Controller
  def index
    authorize! :read, Invitation

    render json: serialized_response(session_invitations_scope)
  end

  def create
    return head :not_acceptable unless session_load.published?

    authorize! :create, Invitation
    targets.each do |target|
      session_load.invite_by_email(target[:emails], target[:health_clinic_id])
    end

    render json: serialized_response(session_invitations_scope), status: :created
  end

  def destroy
    session_invitations_load.destroy!
    head :no_content
  end

  private

  def session_load
    Session.accessible_by(current_ability).find(params[:session_id])
  end

  def session_invitations_scope
    session_load.invitations
  end

  def session_invitations_load
    session_invitations_scope.find(params[:id])
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
