# frozen_string_literal: true

class SessionScheduleJob < ApplicationJob
  queue_as :default

  def perform(session_id, user_id, health_clinic = nil, user_intervention_id = nil)
    user_intervention = UserIntervention.find_by(id: user_intervention_id)

    return if user_intervention.blank?
    return if user_intervention.intervention.paused?

    user_intervention.update!(status: :in_progress)

    session = Session.find_by(id: session_id)
    user = User.find_by(id: user_id)
    session&.send_link_to_session(user, health_clinic) if user
  end
end
