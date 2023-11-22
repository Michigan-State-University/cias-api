# frozen_string_literal: true

class Interventions::PauseJob < ApplicationJob
  def perform(intervention_id)
    intervention = Intervention.find(intervention_id)
    intervention.update(paused_at: DateTime.now)
    # UserSessionTimeoutJob - done
    user_sessions = UserSession.where(session_id: intervention.sessions.select(:id))
    user_sessions.each(&:cancel_timeout_job)
    # scheduling - the job responsible for scheduling will be recognize if the intervention is paused and if it is exit the task without any further actions
    # SMS - cleared
    SmsPlans::CancelScheduledSmses.call(intervention_id)
  end
end
