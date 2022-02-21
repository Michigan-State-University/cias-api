# frozen_string_literal: true

class CloneJobs::Intervention < CloneJob
  def perform(user, intervention_id, clone_params)
    intervention = Intervention.find(intervention_id)
    cloned_intervention = intervention.clone(params: clone_params)

    return unless user.email_notification


    send_emails(user, intervention, cloned_intervention)
  rescue StandardError
    return unless user.email_notification

    CloneMailer.error(user).deliver_now
  end

  private

  def send_emails(user, intervention, cloned_interventions)
    return CloneMailer.cloned_intervention(user, intervention.name, cloned_interventions.id).deliver_now unless cloned_interventions.is_a?(Array)

    cloned_interventions.each do |cloned_intervention|
      CloneMailer.cloned_intervention(cloned_intervention.user, intervention.name, cloned_intervention.id).deliver_now
    end
  end
end
