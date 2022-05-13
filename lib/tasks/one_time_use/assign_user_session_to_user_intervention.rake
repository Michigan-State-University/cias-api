# frozen_string_literal: true

namespace :user_session do
  desc 'assign existing user_session to user_intervention'
  task assign_user_session_to_user_intervention: :environment do
    UserSession.all.each do |user_session|
      user_intervention = UserIntervention.find_or_initialize_by(
        user_id: user_session.user_id,
        intervention_id: user_session.session.intervention.id,
        health_clinic_id: user_session.health_clinic_id
      )
      user_intervention.completed_sessions += 1

      user_intervention.status = 'completed' if user_intervention_is_completed?(user_intervention)
      user_intervention.save!

      assign_correct_status(user_intervention, user_session)

      user_intervention.user_sessions << user_session
      p "assign session with id = #{user_session.id}"
    end
    p 'done!'
  end

  def assign_correct_status(user_intervention, user_session)
    user_intervention.status = 'in_progress' if session_in_progress?(user_session)
    user_intervention.status = 'completed' if user_intervention_is_completed?(user_intervention)

    user_intervention.save!
  end

  def user_intervention_is_completed?(user_intervention)
    last_session = user_intervention.intervention.sessions.last
    user_intervention.user_sessions.where(session_id: last_session.id).any?
  end

  def session_in_progress?(user_session)
    return true if user_session.type.eql?('UserSession::CatMh')

    user_session.answers.any?
  end
end
