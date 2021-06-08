# frozen_string_literal: true

# Controller returns all users who have access to all session associated with the intervention
# if intervention is shared to only selected registered participant;
class V1::Interventions::InvitationsController < V1Controller
  def index
    render json: serialized_response(user_with_access_scope)
  end

  def create
    return head :not_acceptable if intervention_load.closed? || intervention_load.archived?

    authorize! :create, Invitation

    intervention_load.give_user_access(user_session_params[:emails])
    render json: serialized_response(user_with_access_scope), status: :created
  end

  def destroy
    return head :not_acceptable if intervention_load.closed? || intervention_load.archived?

    user_with_access_scope.find(params[:id]).destroy
    head :no_content
  end

  private

  def intervention_load
    Intervention.accessible_by(current_ability).find(params[:intervention_id])
  end

  def user_with_access_scope
    intervention_load.invitations
  end

  def user_session_params
    params.require(:user_session).permit(emails: [])
  end
end
