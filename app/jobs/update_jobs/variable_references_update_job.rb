# frozen_string_literal: true

# rubocop:disable Rails/SkipsModelValidations
class UpdateJobs::VariableReferencesUpdateJob < CloneJob
  sidekiq_retries_exhausted do |msg, _ex|
    question_id = msg['args'].first
    question = Question.find_by(id: question_id)
    session_id = question&.session&.id

    if session_id
      Session.where(id: session_id).update_all(formula_update_in_progress: false, updated_at: Time.current)
    else
      Rails.logger.error "[#{name}] Job failed permanently and could not find session_id to release lock. Args: #{msg['args']}"
    end
  end

  private

  def with_formula_update_lock(session_id)
    session = Session.find_by(id: session_id)

    if session.nil?
      Rails.logger.warn "[#{self.class.name}] Skipping job, Session #{session_id} not found."
      return
    end

    unless session.formula_update_in_progress?
      Rails.logger.warn "[#{self.class.name}] Skipping job, formula update lock not held for session #{session_id}"
      return
    end

    begin
      yield session
    rescue StandardError => e
      Rails.logger.error "[#{self.class.name}] Failed to update formula references, will retry. Lock remains held. Error: #{e.message}"
      Rails.logger.error "[#{self.class.name}] Backtrace: #{e.backtrace.join("\n")}"
      raise e
    end

    Session.where(id: session_id).update_all(formula_update_in_progress: false, updated_at: Time.current)
  end
end
# rubocop:enable Rails/SkipsModelValidations
