# frozen_string_literal: true

class UpdateJobs::AdjustSessionVariableReferences < UpdateJobs::VariableReferencesUpdateJob
  def perform(session_id, old_session_variable, new_session_variable)
    with_formula_update_lock(session_id) do
      next if old_session_variable == new_session_variable
      next if old_session_variable.blank? || new_session_variable.blank?

      V1::VariableReferences::SessionService.call(
        session_id,
        old_session_variable,
        new_session_variable
      )
    end
  end
end
