# frozen_string_literal: true

class DuplicateJobs::Session < DuplicateJob
  def perform(user, session_id, new_intervention_id)
    new_intervention = Intervention.accessible_by(user.ability).find(new_intervention_id)
    old_session = Session.accessible_by(user.ability).find(session_id)
    new_position = new_intervention.sessions.order(:position).last&.position.to_i + 1
    new_variable = "duplicated_#{old_session.variable}_#{new_position}"
    Clone::Session.new(
      old_session,
      intervention_id: new_intervention.id,
      clean_formulas: true,
      variable: new_variable,
      position: new_position
    ).execute(clone_single_session: true)

    return unless user.email_notification

    DuplicateMailer.confirmation(user, old_session, new_intervention).deliver_now
  rescue StandardError
    return unless user.email_notification

    CloneMailer.error(user).deliver_now
  end
end
