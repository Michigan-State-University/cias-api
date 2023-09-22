# frozen_string_literal: true

namespace :one_time_use do
  desc <<-DESC
This task will restore SessionScheduleJobs based on UserSessions that have not yet been started,
but have the scheduled_at parameter set to some date (not nil).
It will also avoid creating duplicate sidekiq jobs, in case a ScheduleSessionJob already exists for the same parameters.
However, it won't restore any scheduling for UserSessions that have not been scheduled by V1::UserSessionScheduleService.
For this, you will need to run `rake one_time_use:recreate_timeout_jobs` before running this task.
  DESC
  task recreate_session_schedule_jobs: :environment do
    user_sessions_count = user_sessions.count
    puts "Found #{user_sessions_count} candidate user sessions"
    user_sessions.find_each.with_index(1) do |user_session, i|
      puts "Processing #{i}/#{user_sessions_count}"
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
