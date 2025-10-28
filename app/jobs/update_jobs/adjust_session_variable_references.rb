# frozen_string_literal: true

class UpdateJobs::AdjustSessionVariableReferences < UpdateJobs::VariableReferencesUpdateJob
  def perform(session_id, old_session_variable, new_session_variable)
    return if old_session_variable == new_session_variable
    return if old_session_variable.blank? || new_session_variable.blank?

    session = Session.find(session_id)

    with_formula_update_lock(session.intervention_id) do
      V1::VariableReferences::SessionService.call(
        session_id,
        old_session_variable,
        new_session_variable
      )
    end
  end
end
