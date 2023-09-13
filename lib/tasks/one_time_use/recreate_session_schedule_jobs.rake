# frozen_string_literal: true

namespace :one_time_use do
  desc 'Rename suprised to surprised'
  task recreate_session_schedule_jobs: :environment do
    user_sessions.find_each do |user_session|
      if user_session.scheduled_at.past?
        perform_due_schedule(user_session)
      else
        recreate_schedule_job(user_session)
      end
    end
  end
end

private

def user_sessions
  UserSession.where(started: false)
end

def perform_due_schedule(user_session)

end

def recreate_schedule_job(user_session)
  SessionScheduleJob.set(wait_until: user_session.scheduled_at).perform_later(
    user_session.session.id,
    user_session.user.id,
    user_session.health_clinic,
    user_session.user_intervention.id
  )
end
