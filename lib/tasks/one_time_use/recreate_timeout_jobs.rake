# frozen_string_literal: true

namespace :one_time_use do
  desc <<-DESC
This is the main rake task that will restore the jobs, as well as additional info for the other two tasks for them to restore it. \
The main goals of this task are: \
- recreate the UserSessionTimeoutJobs based on the last answer made by a participant and the session autofinish delay. \
- it also recreates the scheduling for the next session - it executes branching (if needed) and creates a new UserSession. \
  with the correct scheduled_at parameter, however, it won't recreate SessionScheduleJobs, please use a separate rake task for it.
  DESC
  task recreate_timeout_jobs: :environment do
    class RecreateUserSessionScheduleService < V1::UserSessionScheduleService
      def initialize(user_session, now)
        @now = now # define your own now
        super(user_session)
      end

      attr_reader :user_session, :now, :all_var_values, :all_var_values_with_session_variables, :health_clinic
      attr_accessor :next_user_session, :user_intervention

      def after_fill_schedule(next_session)
        next_user_session.update!(scheduled_at: now)
        next_session.send_link_to_session(user_session.user, health_clinic)
      end

      def days_after_fill_schedule(next_session)
        user_intervention.update!(status: :schedule_pending)
        next_user_session.update!(scheduled_at: (now + next_session.schedule_payload.days))
        # SessionScheduleJob.set(wait: next_session.schedule_payload.days).perform_later(next_session.id, user_session.user.id, health_clinic)
      end

      def schedule_until(date_of_schedule, next_session)
        return unless date_of_schedule

        if date_of_schedule.past?
          user_intervention.update!(status: :in_progress)
          next_session.send_link_to_session(user_session.user, health_clinic)
          return
        end

        user_intervention.update!(status: :schedule_pending)
        next_user_session.update!(scheduled_at: date_of_schedule)
        # SessionScheduleJob.set(wait_until: date_of_schedule).perform_later(next_session.id, user_session.user.id, health_clinic, user_intervention.id)
      end
    end

    user_sessions_count = user_sessions.count
    puts "Found #{user_sessions_count} candidate user sessions"
    user_sessions.find_each.with_index(1) do |user_session, i|
      puts "Processing #{i}/#{user_sessions_count}"
      estimated_timeout_time = user_session.last_answer_at + user_session.session.autofinish_delay.minutes
      if estimated_timeout_time.future?
        recreate_timeout_job_for_user_session(user_session, estimated_timeout_time)
      elsif user_session.class == UserSession::Classic
        finish_due_classic_user_session(user_session, estimated_timeout_time)
      elsif user_session.class == UserSession::CatMh
        finish_due_catmh_user_session(user_session, estimated_timeout_time)
      end
    end
  end
end

private

def user_sessions
  UserSession.joins(:session)
             .where(finished_at: nil)
             .where.not(last_answer_at: nil)
             .where(sessions: {autofinish_enabled:  true})
end

def recreate_timeout_job_for_user_session(user_session, timeout_datetime)
  job_exists = scheduled_set.each do |job|
    break true if job['args'].first >= {
      "job_class" => "UserSessionTimeoutJob",
      "arguments" => [user_session.id]
    }
  end || false

  UserSessionTimeoutJob.set(wait_until: timeout_datetime).perform_later(user_session.id) unless job_exists
end

def finish_due_classic_user_session(user_session, timeout_datetime)
  user_session.update(finished_at: timeout_datetime)
  user_session.send(:delete_alternative_answers)
  user_session.reload

  user_session.send(:decrement_audio_usage)

  RecreateUserSessionScheduleService.new(user_session, timeout_datetime).schedule
  V1::ChartStatistics::CreateForUserSession.call(user_session)

  AfterFinishUserSessionJob.perform_later(user_session.id, user_session.session.intervention)

  user_session.update_user_intervention(session_is_finished: true)
end

def finish_due_catmh_user_session(user_session, timeout_datetime)
  user_session.update!(finished_at: timeout_datetime)

  cat_mh_api = Api::CatMh.new

  result = cat_mh_api.get_result(user_session)
  result_to_answers(user_session, result['body']) if result['status'] == 200
  cat_mh_api.terminate_intervention(user_session)

  RecreateUserSessionScheduleService.new(user_session, timeout_datetime).schedule
  GenerateUserSessionReportsJob.perform_later(user_session.id)

  V1::ChartStatistics::CreateForUserSession.call(user_session)

  user_session.update_user_intervention(session_is_finished: true)
end

def scheduled_set
  @scheduled_set ||= Sidekiq::ScheduledSet.new
end

def result_to_answers(user_session, result)
  available_test_types = user_session.session.cat_mh_test_types
  result['tests'].each do |test|
    test_type = available_test_types.find_by(short_name: test['type'].downcase)
    test_type.cat_mh_test_attributes.each do |variable|
      Answer::CatMh.create!(
        user_session_id: user_session.id,
        body: {
          'data' => [
            { 'var' => "#{test_type.short_name}_#{variable.name}", 'value' => test[variable.name] }
          ]
        }
      )
    end
  end
end
