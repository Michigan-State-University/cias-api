# frozen_string_literal: true

class CloneJobs::Session < CloneJob
  def perform(user, session)
    intervention = session.intervention
    position = intervention.sessions.order(:position).last.position + 1
    params = { variable: "cloned_#{session.variable}_#{position}" }
    cloned_session = session.clone(params: params, clean_formulas: false)

    return unless user.email_notification

    CloneMailer.with(locale: session.language_code).cloned_session(user, session.name, cloned_session).deliver_now
  rescue StandardError
    return unless user.email_notification

    CloneMailer.with(locale: session.language_code).error(user).deliver_now
  end
end
