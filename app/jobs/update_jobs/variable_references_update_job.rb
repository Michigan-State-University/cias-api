# frozen_string_literal: true

class UpdateJobs::VariableReferencesUpdateJob < CloneJob
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  retry_on ActiveRecord::LockWaitTimeout, wait: 5.seconds, attempts: 3

  private

  def with_formula_update_lock(intervention_id)
    # rubocop:disable Rails/SkipsModelValidations
    lock_acquired = Intervention
          .where(id: intervention_id, formula_update_in_progress: false)
          .update_all(formula_update_in_progress: true, updated_at: Time.current)

    if lock_acquired.zero?
      Rails.logger.warn "[#{self.class.name}] Skipping job, formula update already in progress for intervention #{intervention_id}."
      return
    end

    begin
      intervention = Intervention.find(intervention_id)
      yield intervention
    rescue StandardError => e
      Rails.logger.error "[#{self.class.name}] Failed to update formula references: #{e.message}"
      Rails.logger.error "[#{self.class.name}] Backtrace: #{e.backtrace.join("\n")}"
      raise
    ensure
      Intervention.where(id: intervention_id).update_all(formula_update_in_progress: false, updated_at: Time.current)
    end
    # rubocop:enable Rails/SkipsModelValidations
  end
end
