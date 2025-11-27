# frozen_string_literal: true

# rubocop:disable Rails/SkipsModelValidations
module VariableReferencesLockManagement
  extend ActiveSupport::Concern

  included do
    def session_id_for_lock_cleanup
      raise NotImplementedError, "#{self.class.name} must implement #session_id_for_lock_cleanup"
    end

    sidekiq_retries_exhausted do |msg, _ex|
      job_class = msg['class'].constantize
      job_instance = job_class.new

      begin
        job_instance.deserialize(msg)
        session_id = job_instance.session_id_for_lock_cleanup

        if session_id
          Session.where(id: session_id).update_all(
            formula_update_in_progress: false,
            updated_at: Time.current
          )
          Rails.logger.info "[#{job_class.name}] Released lock for session #{session_id} after retries exhausted"
        else
          Rails.logger.error "[#{job_class.name}] Could not determine session_id to release lock. Args: #{msg['args']}"
        end
      rescue StandardError => e
        Rails.logger.error "[#{job_class.name}] Failed to release lock on retry exhaustion: #{e.message}"
        Rails.logger.error "[#{job_class.name}] Args: #{msg['args']}"
      end
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
