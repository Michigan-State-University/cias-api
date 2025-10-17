# frozen_string_literal: true

class UpdateJobs::AdjustSessionVariableReferences < CloneJob
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  retry_on ActiveRecord::LockWaitTimeout, wait: 5.seconds, attempts: 3

  def perform(session_id, old_session_variable, new_session_variable)
    V1::VariableReferencesUpdate.update_session_variable_references(session_id, old_session_variable, new_session_variable)
  end
end
