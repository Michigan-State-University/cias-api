# frozen_string_literal: true

class V1::UserSessionScheduleService
  def initialize(user_session)
    @user_session = user_session
  end

  attr_reader :user_session

  def schedule
    next_session = branch_to_session
    return if next_session.nil?

    send("#{next_session.schedule}_schedule", next_session)
  end

  def after_fill_schedule(next_session)
    next_session.send_link_to_session(user_session.user)
  end

  def days_after_schedule(next_session)
    SessionEmailScheduleJob.set(wait_until: next_session.schedule_at.noon).perform_later(next_session.id, user_session.user.id)
  end

  def days_after_fill_schedule(next_session)
    SessionEmailScheduleJob.set(wait: next_session.schedule_payload.days).perform_later(next_session.id, user_session.user.id)
  end

  def exact_date_schedule(next_session)
    SessionEmailScheduleJob.set(wait_until: next_session.schedule_at.noon).perform_later(next_session.id, user_session.user.id)
  end

  def branch_to_session
    next_session = user_session.session.next_session
    session = user_session.session
    if session.settings['formula']
      formula_result = session.exploit_formula(user_session.all_var_values)
      next_session = Session.find(formula_result['target']['id']) if formula_result.is_a?(Hash)
    end
    next_session
  end
end
