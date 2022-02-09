# frozen_string_literal: true

class CloneJobs::Session < CloneJob
  def perform(user, session)
    intervention = session.intervention
    position = intervention.sessions.order(:position).last.position + 1
    params = { variable: "cloned_#{session.variable}_#{position}" }
    cloned_session = session.clone(params: params)

    return unless user.email_notification

    CloneMailer.cloned_session(user, session.name, cloned_session).deliver_now
  rescue StandardError

    return unless user.email_notification

    CloneMailer.error(user).deliver_now
  end
end
