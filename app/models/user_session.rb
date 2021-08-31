# frozen_string_literal: true

class UserSession < ApplicationRecord
  has_paper_trail
  belongs_to :user, inverse_of: :user_sessions
  belongs_to :session, inverse_of: :user_sessions
  has_many :answers, dependent: :destroy
  has_many :generated_reports, dependent: :destroy
  belongs_to :health_clinic, optional: true

  def finish(_send_email: true)
    raise NotImplementedError, "subclass did not define #{__method__}"
  end

  def cancel_timeout_job
    return if timeout_job_id.nil?

    UserSessionTimeoutJob.cancel(timeout_job_id)
    update(timeout_job_id: nil)
  end

  def all_var_values(include_session_var: true)
    answers.each_with_object({}) do |answer, var_values|
      answer.body_data.each do |obj|
        key = include_session_var ? "#{session.variable}.#{obj['var']}" : obj['var']
        var_values[key] = obj['value']
      end
    end
  end

  def search_var(var_to_look_for, include_session_var: false)
    answers.each do |answer|
      answer.body_data.each do |obj|
        var_name = include_session_var ? "#{session.variable}.#{obj['var']}" : obj['var']
        return obj['value'] if var_name.eql?(var_to_look_for)
      end
    end
    nil
  end
end
