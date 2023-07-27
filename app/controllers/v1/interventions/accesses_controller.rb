# frozen_string_literal: true

class V1::Interventions::AccessesController < V1Controller
  def index
    render json: serialized_response(intervention_access_scope, 'InterventionAccess')
  end

  def create
    intervention = intervention_load
    return head :not_acceptable if intervention.closed? || intervention.archived?

    authorize! :create, InterventionAccess
    authorize! :update, intervention

    intervention.give_user_access(user_session_params[:emails])
    render json: serialized_response(intervention.reload.intervention_accesses, 'InterventionAccess'), status: :created
  end

  def destroy
    authorize! :update, intervention_load

    access_load.destroy!

    head :no_content
  end

  private

  def user_session_params
    params.require(:user_session).permit(emails: [])
  end

  def access_params
    params.permit(:id, :email, :intervention_id)
  end

  def intervention_access_scope
    intervention_load.intervention_accesses
  end

  def access_load
    intervention_access_scope.find(access_params[:id])
  end

  def intervention_id
    params[:intervention_id]
  end

  def intervention_load
    @intervention_load ||= Intervention.find(intervention_id)
  end
end
