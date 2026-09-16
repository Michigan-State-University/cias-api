# frozen_string_literal: true

class DuplicateJobs::Session < DuplicateJob
  def perform(user, session_id, new_intervention_id)
    new_intervention = Intervention.accessible_by(user.ability).find(new_intervention_id)
    old_session = Session.accessible_by(user.ability).find(session_id)

    if old_session.type == 'Session::ResearchAssistant' &&
       new_intervention.sessions.exists?(type: 'Session::ResearchAssistant')
      raise ComplexException.new(
        I18n.t('sessions.ra_already_exists_in_target'),
        {},
        :unprocessable_entity
      )
    end

    new_position = new_intervention.sessions.order(:position).last&.position.to_i + 1
    new_variable = "duplicated_#{old_session.variable}_#{new_position}"
    Clone::Session.new(
      old_session,
      intervention_id: new_intervention.id,
      clean_formulas: true,
      variable: new_variable,
      position: new_position
    ).execute

    return unless user.email_notification

    DuplicateMailer.confirmation(user, old_session, new_intervention).deliver_now
  rescue StandardError
    return unless user.email_notification

    CloneMailer.error(user).deliver_now
  end
end
