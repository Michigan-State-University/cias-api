# frozen_string_literal: true

class UserSession < ApplicationRecord
  has_paper_trail
  belongs_to :user, inverse_of: :user_sessions
  belongs_to :user_intervention, inverse_of: :user_sessions
  belongs_to :session, inverse_of: :user_sessions
  has_many :answers, dependent: :destroy
  has_many :generated_reports, dependent: :destroy
  belongs_to :health_clinic, optional: true

  def finish(_send_email: true)
    raise NotImplementedError, "subclass did not define #{__method__}"
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

  def update_user_intervention(session_is_finished: false)
    user_intervention.completed_sessions += 1 if session_is_finished

    if user_intervention_finished?
      user_intervention.status = 'completed'
      user_intervention.finished_at = DateTime.current
    else
      user_intervention.status = 'in_progress'
    end

    user_intervention.save!
  end

  private

  def user_intervention_finished?
    return user_intervention.completed_sessions == user_intervention.user_sessions.size unless user_intervention.intervention.module_intervention?

    user_intervention.completed_sessions == user_intervention.sessions.size
  end
end
