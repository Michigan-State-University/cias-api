# frozen_string_literal: true

class UserSession::Classic < UserSession
  belongs_to :name_audio, class_name: 'Audio', optional: true

  def on_answer
    timeout_job = UserSessionTimeoutJob.set(wait: 1.day).perform_later(id)
    cancel_timeout_job
    update(last_answer_at: DateTime.current, timeout_job_id: timeout_job.job_id)
  end

  def cancel_timeout_job
    return if timeout_job_id.nil?

    UserSessionTimeoutJob.cancel(timeout_job_id)
    update(timeout_job_id: nil)
  end

  def last_answer
    answers.order(:created_at).last
  end

  private

  def decrement_audio_usage
    return if name_audio.nil?

    name_audio.decrement(:usage_counter)
    name_audio.save!
  end
end
