# frozen_string_literal: true

class UpdateJobs::AdjustSessionVariableReferences < CloneJob
  include VariableReferencesLockManagement

  def perform(session_id, old_session_variable, new_session_variable)
    return if old_session_variable == new_session_variable
    return if old_session_variable.blank? || new_session_variable.blank?

    @session_id = session_id

    with_formula_update_lock(@session_id) do
      next if old_session_variable == new_session_variable
      next if old_session_variable.blank? || new_session_variable.blank?

      V1::VariableReferences::SessionService.call(
        session_id,
        old_session_variable,
        new_session_variable
      )
    end
  end

  private

  def session_id_for_lock_cleanup
    @session_id
  end
end
