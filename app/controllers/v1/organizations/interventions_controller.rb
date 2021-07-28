# frozen_string_literal: true

class V1::Organizations::InterventionsController < V1Controller
  def index
    authorize! :read, Intervention

    render json: serialized_response(interventions_scope)
  end

  private

  def interventions_scope
    Intervention.with_any_organization.accessible_by(current_ability).where(organization_id: params[:organization_id])
  end
end
