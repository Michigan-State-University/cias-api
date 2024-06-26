# frozen_string_literal: true

class UserSession < ApplicationRecord
  has_paper_trail
  belongs_to :user, inverse_of: :user_sessions
  belongs_to :user_intervention, inverse_of: :user_sessions
  belongs_to :session, inverse_of: :user_sessions
  has_many :answers, dependent: :destroy
  has_many :generated_reports, dependent: :destroy
  has_many :tlfb_days, class_name: 'Tlfb::Day', dependent: :destroy
  belongs_to :health_clinic, optional: true

  validates :health_clinic_id, presence: true, if: -> { user_intervention_inside_health_clinic? && !preview? }

  before_create :check_uniqueness

  def finish(_send_email: true)
    raise NotImplementedError, "subclass did not define #{__method__}"
  end

  def all_var_values(include_session_var: true)
    answers.confirmed.each_with_object({}) do |answer, var_values|
      answer.body_data.each do |obj|
        key = include_session_var ? "#{session.variable}.#{obj['var'].tr('/', '')}" : obj['var'].tr('/', '')
        var_values[key] = map_to_numeric_value(obj, answer)
      end
    end
  end

  def map_to_numeric_value(obj, answer)
    return obj['value'] unless answer.class.in? [Answer::ParticipantReport, Answer::Phone, Answer::ThirdParty]

    case answer.class.name
    when 'Answer::ParticipantReport'
      (obj['value']['receive_report'] && 1) || 0
    when 'Answer::Phone'
      (obj['value']['confirmed'] && 1) || 0
    when 'Answer::ThirdParty'
      obj['numeric_value']
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
    user_intervention.completed_sessions += 1 if session_is_finished && UserSession.where(user_id: user_id, session_id: session_id).size < 2

    if user_intervention_finished?
      user_intervention.status = 'completed'
      user_intervention.finished_at = DateTime.current
    elsif user_intervention.ready_to_start?
      user_intervention.status = 'in_progress'
    end

    user_intervention.save!
  end

  def filled_out_count
    user_intervention.user_sessions.where(session_id: session_id).where.not(finished_at: nil).count
  end

  private

  def user_intervention_finished?
    return session.last_session? && finished_at.present? unless user_intervention.intervention.module_intervention?

    user_intervention.completed_sessions == user_intervention.sessions.size
  end

  def preview?
    user.role?('preview_session')
  end

  def user_intervention_inside_health_clinic?
    user_intervention&.health_clinic_id.present?
  end

  def check_uniqueness
    raise ActiveRecord::RecordNotUnique, 'There already exists a user session for this user and session' unless user_and_session_unique?
  end

  def user_and_session_unique?
    UserSession.joins(:session).where(session: { multiple_fill: false }).find_by(user_id: user_id, session_id: session_id).blank?
  end
end
