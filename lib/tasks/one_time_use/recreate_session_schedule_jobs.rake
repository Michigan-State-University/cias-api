# frozen_string_literal: true

namespace :one_time_use do
  task recreate_session_schedule_jobs: :environment do
    p user_sessions.count
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
  UserSession.where(started: false).where.not(scheduled_at: nil)
end

def perform_due_schedule(user_session)
  SessionScheduleJob.perform_now(
    user_session.session.id,
    user_session.user.id,
    user_session.health_clinic,
    user_session.user_intervention.id
  )
end

def recreate_schedule_job(user_session)
  job_exists = scheduled_set.each do |job|
    p job['args'].first
    break true if job['args'].first >= {
      "job_class" => "SessionScheduleJob",
      "arguments" => [
        user_session.session.id,
        user_session.user.id,
        user_session.health_clinic,
        user_session.user_intervention.id
      ]
    }
  end || false

  return if job_exists

  SessionScheduleJob.set(wait_until: user_session.scheduled_at).perform_later(
    user_session.session.id,
    user_session.user.id,
    user_session.health_clinic,
    user_session.user_intervention.id
  )
end

def scheduled_set
  @scheduled_set ||= Sidekiq::ScheduledSet.new
end
