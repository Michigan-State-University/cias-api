# frozen_string_literal: true

class UpdateJobs::AdjustQuestionVariableReferences < CloneJob
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  retry_on ActiveRecord::LockWaitTimeout, wait: 5.seconds, attempts: 3

  def perform(question_id, old_variable_name, new_variable_name)
    V1::VariableReferencesUpdate.update_question_variable_references(question_id, old_variable_name, new_variable_name)
  end
end
