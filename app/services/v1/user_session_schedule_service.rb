# frozen_string_literal: true

class V1::UserSessionScheduleService
  def initialize(user_session)
    @user_session = user_session
    @all_var_values = V1::UserInterventionService.new(
      user_session.user.id, user_session.session.intervention_id, user_session.id
    ).var_values
    @health_clinic = user_session.health_clinic
  end

  attr_reader :user_session, :all_var_values, :health_clinic

  def schedule
    next_session = branch_to_session
    return if next_session.nil?

    send("#{next_session.schedule}_schedule", next_session)
  end

  def after_fill_schedule(next_session)
    next_session.send_link_to_session(user_session.user, health_clinic)
  end

  def days_after_schedule(next_session)
    SessionEmailScheduleJob.set(wait_until: next_session.schedule_at.noon).perform_later(next_session.id, user_session.user.id, health_clinic)
  end

  def days_after_fill_schedule(next_session)
    SessionEmailScheduleJob.set(wait: next_session.schedule_payload.days).perform_later(next_session.id, user_session.user.id, health_clinic)
  end

  def exact_date_schedule(next_session)
    SessionEmailScheduleJob.set(wait_until: next_session.schedule_at.noon).perform_later(next_session.id, user_session.user.id, health_clinic)
  end

  def days_after_date_schedule(next_session)
    participant_date = all_var_values[next_session.days_after_date_variable_name]

    return unless participant_date

    SessionEmailScheduleJob.set(wait_until: (participant_date.to_datetime + next_session.schedule_payload&.days).noon)
        .perform_later(next_session.id, user_session.user.id, health_clinic)
  end

  def branch_to_session
    next_session = user_session.session.next_session
    session = user_session.session
    if session.settings['formula']
      formula_result = session.exploit_formula(all_var_values)
      target = V1::RandomizationService.new(formula_result['target']).execute unless formula_result.nil?
      next_session = Session.find(target['id']) if target.is_a?(Hash) && !target['id'].nil?
    end
    next_session
  end
end
