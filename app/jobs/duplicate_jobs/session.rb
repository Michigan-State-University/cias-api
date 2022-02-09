# frozen_string_literal: true

class DuplicateJobs::Session < DuplicateJob
  def perform(user, session_id, new_intervention_id)
    new_intervention = Intervention.accessible_by(user.ability).find(new_intervention_id)
    old_session = Session.accessible_by(user.ability).find(session_id)
    new_position = new_intervention.sessions.order(:position).last&.position.to_i + 1
    new_variable = "duplicated_#{old_session.variable}_#{new_position}"
    Clone::Session.new(old_session,
                       intervention_id: new_intervention.id,
                       clean_formulas: true,
                       variable: new_variable,
                       position: new_position).execute

    return unless user.email_notification
  #   intervention = session.intervention
  #   position = intervention.sessions.order(:position).last.position + 1
  #   params = { variable: "cloned_#{session.variable}_#{position}" }
  #   cloned_session = session.clone(params: params)
  #
  #   return unless user.email_notification
  #
  #   CloneMailer.cloned_session(user, session.name, cloned_session).deliver_now
  # rescue StandardError
  #
  #   return unless user.email_notification
  #
  #   CloneMailer.error(user).deliver_now
  end
end
