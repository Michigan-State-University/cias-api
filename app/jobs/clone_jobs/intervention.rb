# frozen_string_literal: true

class CloneJobs::Intervention < CloneJob
  def perform(user, intervention_id, clone_params)
    intervention = Intervention.find(intervention_id)

    cloned_interventions = intervention.clone(params: clone_params)
    cloned_interventions = Array([:existing, cloned_interventions]) unless cloned_interventions.is_a?(Array)

    after_clone(intervention, cloned_interventions)
  rescue StandardError => e
    logger.error 'ERROR-LOG'
    logger.error e
    logger.error e.message
    logger.error 'ERROR-LOG-END'
    CloneMailer.error(user).deliver_now

    cloned_interventions = Array([:existing, cloned_interventions]) unless cloned_interventions.is_a?(Array)
    clear_invalid_interventions(cloned_interventions)
  end

  private

  def after_clone(intervention, cloned_interventions)
    cloned_interventions.each do |type, cloned_intervention|
      Intervention.reset_counters(cloned_intervention.id, :sessions)
      next unless cloned_intervention.user.email_notification

      if type == :existing
        CloneMailer.cloned_intervention(cloned_intervention.user, intervention.name, cloned_intervention.id).deliver_now
      else
        InterventionMailer.share_externally_and_registration(cloned_intervention, cloned_intervention.user.email).deliver_now
      end
    end
  end

  def clear_invalid_interventions(cloned_interventions)
    cloned_interventions&.each { |_type, intervention| clear_invalid_intervention(intervention) }
  end

  def clear_invalid_intervention(cloned_intervention)
    cloned_intervention&.sessions&.destroy_all
    cloned_intervention&.destroy
  end
end
