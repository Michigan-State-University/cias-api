# frozen_string_literal: true

class Interventions::PauseJob < ApplicationJob
  def perform(intervention_id)
    intervention = Intervention.find(intervention_id)
    intervention.update(paused_at: DateTime.now)

    UserSession.where(session_id: intervention.sessions.select(:id)).each(&:cancel_timeout_job)
    V1::SmsPlans::CancelScheduledSmses.call(intervention_id)
  end
end
