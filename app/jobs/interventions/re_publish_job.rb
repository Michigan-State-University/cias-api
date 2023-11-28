# frozen_string_literal: true

class Interventions::RePublishJob < ApplicationJob
  def perform(intervention_id)
    intervention = Intervention.find(intervention_id)
    user_session = UserSession.where(session_id: intervention.sessions.select(:id))

    send_scheduled_invitation_from_past(user_session, intervention)
    reschedule_canceled_smses(user_session)
  end

  private

  def send_scheduled_invitation_from_past(user_sessions, intervention)
    user_sessions.where(scheduled_at: intervention.paused_at..DateTime.now).each do |user_session|
      user_session.session.send_link_to_session(user_session.user, user_session.health_clinic)
    end
  end

  def reschedule_canceled_smses(user_sessions)
    user_sessions.each do |user_session|
      V1::SmsPlans::ReScheduleSmsForUserSession.call(user_session)
    end
  end
end
