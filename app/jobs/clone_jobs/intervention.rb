# frozen_string_literal: true

class CloneJobs::Intervention < CloneJob
  def perform(user, intervention_id, clone_params)
    intervention = Intervention.find(intervention_id)

    cloned_intervention = intervention.clone(params: clone_params)

    return after_self_duplication(user, intervention, cloned_intervention) if clone_params[:user_ids].blank?

    after_share(intervention, cloned_intervention)
  rescue StandardError => e
    logger.error 'ERROR-LOG'
    logger.error e
    logger.error e.message
    logger.error 'ERROR-LOG-END'
    CloneMailer.error(user).deliver_now

    return clear_invalid_intervention(cloned_intervention) if clone_params[:user_ids].blank?

    cloned_intervention&.each { |intervention| clear_invalid_intervention(intervention) }
  end

  private

  def after_self_duplication(user, intervention, cloned_intervention)
    cloned_intervention.update!(is_cloning: false)

    return unless user.email_notification

    CloneMailer.cloned_intervention(user, intervention.name, cloned_intervention.id).deliver_now
  end

  def after_share(intervention, cloned_interventions)
    cloned_interventions.each do |cloned_intervention|
      cloned_intervention.update!(is_cloning: false)
      CloneMailer.cloned_intervention(cloned_intervention.user, intervention.name, cloned_intervention.id).deliver_now
    end
  end

  def clear_invalid_intervention(cloned_intervention)
    cloned_intervention&.sessions&.destroy_all
    cloned_intervention&.destroy
  end
end
