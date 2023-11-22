# frozen_string_literal: true

class Interventions::RePublishJob < ApplicationJob
  def perform(intervention_id)
    intervention = Intervention.find(intervention_id)
    # scheduling - the job responsible for scheduling will be recognize if the intervention is paused and if it is exit the task without any further actions
    # SMS - cleared
    user_session = UserSession.where(session_id: intervention.sessions.select(:id))

    #scheduling
    user_session.where(scheduled_at: intervention_id.paused_at..DateTime.now).each do |user_session|
      user_session.session.send_link_to_session(user_session.user, user_session.health_clinic)
    end

    #SMSes
    user_session.each do |user_session|
      user = user_session
      next unless user.sms_notification
      next unless user.phone.present? && user.phone.confirmed?

      sms_service =V1::SmsPlans::ScheduleSmsForUserSession.new(user_session)
      user_session.session.sms_plans.limit_to_types('SmsPlan::Normal').each do |plan|
        next unless sms_service.send(:can_run_plan?, plan)

        #check if plan.schedule is correct, we don't want to run "after session end"

      end
    end
  end
end
