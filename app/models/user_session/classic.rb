# frozen_string_literal: true

class UserSession::Classic < UserSession
  belongs_to :name_audio, class_name: 'Audio', optional: true

  before_destroy :decrement_audio_usage

  delegate :first_question, to: :session

  def on_answer
    timeout_job = UserSessionTimeoutJob.set(wait: 1.day).perform_later(id)
    cancel_timeout_job
    update(last_answer_at: DateTime.current, timeout_job_id: timeout_job.provider_job_id)
  end

  def cancel_timeout_job
    return if timeout_job_id.nil?

    UserSessionTimeoutJob.cancel(timeout_job_id)

    update(timeout_job_id: nil)
  end

  def last_answer
    answers.order(:created_at).last
  end

  def finish(send_email: true)
    return if finished_at

    cancel_timeout_job
    update(finished_at: DateTime.current)
    reload

    decrement_audio_usage
    V1::SmsPlans::ScheduleSmsForUserSession.call(self)
    V1::UserSessionScheduleService.new(self).schedule if send_email
    V1::ChartStatistics::CreateForUserSession.call(self)

    AfterFinishUserSessionJob.perform_later(id, session.intervention)

    update_user_intervention(session_is_finished: true)
  end

  private

  def decrement_audio_usage
    return if name_audio.nil?

    name_audio.decrement(:usage_counter)
    name_audio.save!
  end
end
