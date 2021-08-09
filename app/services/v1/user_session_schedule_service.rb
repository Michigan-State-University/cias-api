# frozen_string_literal: true

class V1::UserSessionScheduleService
  def initialize(user_session)
    @user_session = user_session
    @user_intervention_service = V1::UserInterventionService.new(user_session.user.id, user_session.session.intervention_id, user_session.id)
    @all_var_values = @user_intervention_service.var_values
    @all_var_values_with_session_variables = @user_intervention_service.var_values(true)
    @health_clinic = user_session.health_clinic
  end

  attr_reader :user_session, :all_var_values, :all_var_values_with_session_variables, :health_clinic

  def schedule
    next_session = branch_to_session
    return if next_session.nil?

    send("#{next_session.schedule}_schedule", next_session)
  end

  def after_fill_schedule(next_session)
    next_session.send_link_to_session(user_session.user, health_clinic)
  end

  def days_after_schedule(next_session)
    schedule_until(next_session.schedule_at&.noon, next_session)
  end

  def days_after_fill_schedule(next_session)
    SessionEmailScheduleJob.set(wait: next_session.schedule_payload.days).perform_later(next_session.id, user_session.user.id, health_clinic)
  end

  def exact_date_schedule(next_session)
    schedule_until(next_session.schedule_at&.noon, next_session)
  end

  def days_after_date_schedule(next_session)
    participant_date = all_var_values_with_session_variables[next_session.days_after_date_variable_name]

    schedule_until((participant_date.to_datetime + next_session.schedule_payload&.days).noon, next_session) if participant_date
  end

  def branch_to_session
    next_session = user_session.session.next_session
    session = user_session.session
    if session.settings['formula']
      formula_result = session.exploit_formula(all_var_values)
      target = V1::RandomizationService.call(formula_result['target']) unless formula_result.nil?
      next_session = Session.find(target['id']) if target.is_a?(Hash) && !target['id'].nil?
    end
    next_session
  end

  def schedule_until(date_of_schedule, next_session)
    return next_session.send_link_to_session(user_session.user, health_clinic) if date_of_schedule&.past?
    return unless date_of_schedule

    SessionEmailScheduleJob.set(wait_until: date_of_schedule).perform_later(next_session.id, user_session.user.id, health_clinic)
  end
end
