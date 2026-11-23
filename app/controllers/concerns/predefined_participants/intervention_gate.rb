# frozen_string_literal: true

module PredefinedParticipants::InterventionGate
  extend ActiveSupport::Concern

  private

  def verify_access
    authorize! :update, Intervention
    authorize! :update, intervention_load
  end

  def require_current_editor
    head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)
  end

  def intervention_load
    @intervention_load ||= Intervention.accessible_by(current_ability).find(intervention_id)
  end

  def intervention_id
    params[:intervention_id]
  end
end
