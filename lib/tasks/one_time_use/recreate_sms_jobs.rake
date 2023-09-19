namespace :one_time_use do
  desc <<-DESC
This task will recreate all the scheduled sms jobs, both the one-time ones, as well as periodic (every day, every month etc). \
The tolerance for assuming it's the same job is 5 hours \
(if the SmsPlans::SendSmsJob has the same arguments and is within a 6 hours range it will be considered the same).
  DESC
  task recreate_sms_jobs: :environment do
    class RestoreScheduleSmsForUserSession < V1::SmsPlans::ScheduleSmsForUserSession
      def send_sms(start_time, content, attachment_url = nil)
        restore_sms_job(start_time, content, user.phone, false, attachment_url = nil)
      end

      def send_alert(start_time, content, phone, attachment_url = nil)
        restore_sms_job(start_time, content, phone, true, attachment_url = nil)
      end

      def after_session_end_schedule(plan)
        set_frequency(user_session.finished_at, plan)
      end

      def now_in_timezone
        @now_in_timezone ||= Time.use_zone(timezone) { user_session.finished_at }
      end

      def restore_sms_job(start_time, content, phone, is_alert, attachment_url = nil)
        return if start_time.past?
        job_exists = scheduled_set.each do |job|
          break true if job['args'].first >= {
            "job_class" => "SmsPlans::SendSmsJob",
            "arguments" => [
              phone.full_number,
              content,
              attachment_url,
              phone.user&.id,
              is_alert,
              user_session.session_id
            ],
          } && job_near_timestamp?(job, start_time)

          break true if job['args'].first >= {
            "job_class" => "SmsPlans::SendSmsJob",
            "arguments" => [
              phone.full_number,
              content,
              attachment_url,
              phone.user&.id,
            ],
          } && job_near_timestamp?(job, start_time)
        end || false

        return if job_exists

        SmsPlans::SendSmsJob.set(wait_until: start_time).perform_later(phone.full_number, content, attachment_url, phone.user&.id, is_alert, user_session.session_id)
      end
    end

    user_sessions_count = user_sessions.count
    puts "Found #{user_sessions_count} candidate user sessions"
    user_sessions.find_each.with_index(1) do |user_session, i|
      puts "Processing #{i}/#{user_sessions_count}"
      RestoreScheduleSmsForUserSession.call(user_session)
    end
  end
end

def scheduled_set
  @scheduled_set ||= Sidekiq::ScheduledSet.new
end

def user_sessions
  UserSession.where.not(finished_at: nil)
end

def job_near_timestamp?(job, timestamp, tolerance=5.hours)
  timestamp - tolerance <= job.at && timestamp + tolerance >= job.at
end
