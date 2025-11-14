# frozen_string_literal: true

class UpdateJobs::VariableReferencesUpdateJob < CloneJob
  # This hook runs when all Sidekiq retries have failed.
  # We MUST release the lock here to prevent an infinite lock.
  sidekiq_retries_exhausted do |msg, ex|
    # Both jobs have `question_id` as the first argument
    question_id = msg['args'].first
    question = Question.find_by(id: question_id)
    intervention_id = question&.session&.intervention_id

    if intervention_id
      Rails.logger.error "[#{name}] Job failed permanently for intervention #{intervention_id}. Releasing lock. Error: #{ex.message}"
      Intervention.where(id: intervention_id).update_all(formula_update_in_progress: false, updated_at: Time.current)
    else
      Rails.logger.error "[#{name}] Job failed permanently and could not find intervention_id to release lock. Args: #{msg['args']}"
    end
  end

  private

  # --- MODIFIED METHOD ---
  # This method now assumes the lock is already acquired.
  # Its job is to execute the block and release the lock ONLY on success.
  def with_formula_update_lock(intervention_id)
    intervention = Intervention.find_by(id: intervention_id)

    if intervention.nil?
      Rails.logger.warn "[#{self.class.name}] Skipping job, Intervention #{intervention_id} not found."
      return
    end

    # Check if the lock is actually held. If it's not
    # (e.g., released by `sidekiq_retries_exhausted` from a *different*
    # job, or manually), we shouldn't run.
    unless intervention.formula_update_in_progress?
      Rails.logger.warn "[#{self.class.name}] Skipping job, formula update lock not held for intervention #{intervention_id}."
      return
    end

    begin
      # Execute the actual work
      yield intervention
    rescue StandardError => e
      # If the job fails, log it and re-raise to trigger a Sidekiq retry.
      # We explicitly DO NOT release the lock, as we want it held
      # until the job succeeds or fails permanently.
      Rails.logger.error "[#{self.class.name}] Failed to update formula references, will retry. Lock remains held. Error: #{e.message}"
      Rails.logger.error "[#{self.class.name}] Backtrace: #{e.backtrace.join("\n")}"
      raise e
    end

    # If we get here, `yield` was successful.
    # We can now safely release the lock.
    Rails.logger.info "[#{self.class.name}] Job completed successfully. Releasing lock for intervention #{intervention_id}."
    Intervention.where(id: intervention_id).update_all(formula_update_in_progress: false, updated_at: Time.current)
  end
  # --- END MODIFIED METHOD ---
end
