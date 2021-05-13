# frozen_string_literal: true

class V1::Organizations::InterventionsController < V1Controller
  def index
    authorize! :read, Intervention
    render_json interventions: interventions_scope, path: v1_interventions_path
  end

  private

  def interventions_scope
    Intervention.with_any_organization.accessible_by(current_ability).where(organization_id: params[:organization_id])
  end
end
