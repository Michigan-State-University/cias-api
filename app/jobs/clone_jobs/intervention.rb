# frozen_string_literal: true

class CloneJobs::Intervention < CloneJob
  def perform(user, intervention_id, clone_params)
    intervention = Intervention.find(intervention_id)
    cloned_intervention = intervention.clone(params: clone_params)

    return unless user.email_notification

    CloneMailer.cloned_intervention(user, intervention.name, cloned_intervention.id).deliver_now
  rescue StandardError => e

    return unless user.email_notification

    CloneMailer.error(user, e.message).deliver_now
  end
end
