# frozen_string_literal: true

class CloneJobs::Intervention < CloneJob
  def perform(user, intervention_id, clone_params)
    intervention = Intervention.find(intervention_id)

    cloned_intervention = intervention.clone(params: clone_params)
    cloned_intervention = Array(cloned_intervention) unless cloned_intervention.is_a?(Array)

    after_clone(intervention, cloned_intervention)
  rescue StandardError => e
    logger.error 'ERROR-LOG'
    logger.error e
    logger.error e.message
    logger.error 'ERROR-LOG-END'
    CloneMailer.error(user).deliver_now

    cloned_intervention = Array(cloned_intervention) unless cloned_intervention.is_a?(Array)
    clear_invalid_interventions(cloned_intervention)
  end

  private

  def after_clone(intervention, cloned_interventions)
    cloned_interventions.each do |cloned_intervention|
      Intervention.reset_counters(cloned_intervention.id, :sessions)
      next unless cloned_intervention.user.email_notification

      CloneMailer.cloned_intervention(cloned_intervention.user, intervention.name, cloned_intervention.id).deliver_now
    end
  end

  def clear_invalid_interventions(cloned_interventions)
    cloned_interventions&.each { |intervention| clear_invalid_intervention(intervention) }
  end

  def clear_invalid_intervention(cloned_intervention)
    cloned_intervention&.sessions&.destroy_all
    cloned_intervention&.destroy
  end
end
