# frozen_string_literal: true

class UserSession < ApplicationRecord
  belongs_to :user, inverse_of: :user_sessions
  belongs_to :session, inverse_of: :user_sessions
  has_many :answers, dependent: :destroy
  belongs_to :name_audio, class_name: 'Audio', optional: true
  has_many :generated_reports, dependent: :destroy

  before_destroy :decrement_audio_usage

  def finish(send_email: true)
    return if finished_at

    cancel_timeout_job
    update(finished_at: DateTime.current)

    GenerateUserSessionReportsJob.perform_later(id)

    decrement_audio_usage
    V1::SmsPlans::ScheduleSmsForUserSession.call(self)
    V1::UserSessionScheduleService.new(self).schedule if send_email
  end

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

  def all_var_values
    answers.each_with_object({}) do |answer, var_values|
      answer.body_data.each do |obj|
        var_values[obj['var']] = obj['value']
      end
    end
  end

  private

  def session_next
    @session_next ||= session.position_grather_than.first
  end

  def decrement_audio_usage
    return if name_audio.nil?

    name_audio.decrement(:usage_counter)
    name_audio.save!
  end
end
