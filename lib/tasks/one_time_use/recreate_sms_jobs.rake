namespace :one_time_use do
  desc <<-DESC
todo
  DESC
  task recreate_sms_jobs: :environment do
    class RestoreScheduleSmsForUserSession < V1::SmsPlans::ScheduleSmsForUserSession
      def send_sms(start_time, content, attachment_url = nil)
        restore_sms_job(start_time, content, user.phone, false, attachment_url = nil)
      end

      def send_alert(start_time, content, phone, attachment_url = nil)
        restore_sms_job(start_time, content, phone, true, attachment_url = nil)
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
          } && start_time - 6.hours < job.at && start_time + 6.hours > job.at
        end || false

        return if job_exists

        SmsPlans::SendSmsJob.set(wait_until: start_time).perform_later(phone.full_number, content, attachment_url, phone.user&.id, is_alert, user_session.session_id)
      end
    end

    UserSession.find_each do |user_session|
      RestoreScheduleSmsForUserSession.call(user_session)
    end
  end
end

def scheduled_set
  @scheduled_set ||= Sidekiq::ScheduledSet.new
end

