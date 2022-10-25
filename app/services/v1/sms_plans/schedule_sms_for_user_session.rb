# frozen_string_literal: true

class V1::SmsPlans::ScheduleSmsForUserSession
  def self.call(user_session)
    new(user_session).call
  end

  def initialize(user_session)
    @user_session = user_session
  end

  def call
    return unless session.intervention.published?
    return unless user.sms_notification

    session.sms_plans.each do |plan|
      next unless can_run_plan?(plan)

      send("#{plan.schedule}_schedule", plan) if plan.alert? || (phone.present? && phone.confirmed?)
    end
  end

  private

  attr_reader :user_session, :user_intervention_service

  def session
    @session ||= user_session.session
  end

  def after_session_end_schedule(plan)
    set_frequency(Time.current, plan)
  end

  def days_after_session_end_schedule(plan)
    return after_session_end_schedule(plan) if plan.schedule_payload.zero?

    start_time = now_in_timezone.next_day(plan.schedule_payload).change({ hour: 13 }).utc
    set_frequency(start_time, plan)
  end

  def can_run_plan?(plan)
    return false if plan.is_used_formula.blank? && plan.no_formula_text.blank?
    return false if plan.is_used_formula && (plan.formula.blank? || plan.variants.empty?)

    true
  end

  def set_frequency(start_time, plan)
    frequency = plan.frequency
    content = sms_content(plan)
    return if content.blank?

    content = insert_variables_into_variant(content)
    finish_date = plan.end_at

    if plan.alert?
      content = prepend_alert_content(content, plan)
      plan.phones.each { |phone| send_alert(start_time, content, phone) }
      return
    end

    if frequency == SmsPlan.frequencies[:once]
      send_sms(start_time, content)
    else
      date = start_time
      while date.to_date <= finish_date.to_date
        send_sms(date.change({ hour: 13 }).utc, content)
        date = date.next_day(number_days[frequency])
      end
    end
  end

  def prepend_alert_content(current_content, plan)
    return "#{I18n.t('sessions.sms_alerts.no_data_provided')}\n#{current_content}" if plan.no_data_included?

    user = user_session.user
    result = +'' # mutable empty string
    if plan.include_full_name? && (user.first_name.present? && user.last_name.present?)
      result << "#{user.full_name}\n"
    else
      # only one of these should be valid because we handle both include checks as separate statements
      result << ("#{user.first_name.presence || I18n.t('sessions.sms_alerts.no_first_name_provided')}\n") if plan.include_first_name
      result << ("#{user.last_name.presence || I18n.t('sessions.sms_alerts.no_last_name_provided')}\n") if plan.include_last_name
    end
    result << ("#{user_email(user) || I18n.t('sessions.sms_alerts.no_email_provided')}\n") if plan.include_email
    result << ("#{user.phone.present? ? user.phone.full_number : I18n.t('sessions.sms_alerts.no_phone_number_provided')}\n") if plan.include_phone_number
    result + current_content
  end

  def sms_content(plan)
    plan.is_used_formula ? matched_variant(plan)&.content : plan.no_formula_text
  end

  def matched_variant(plan)
    all_var_values = V1::UserInterventionService.new(user.id, session.intervention_id, user_session.id).var_values
    V1::SmsPlans::CalculateMatchedVariant.call(plan.formula, plan.variants, all_var_values)
  end

  def name_variable
    @name_variable ||= Answer::Name.find_by(
      user_session_id: user_session.id
    )&.body_data&.first&.dig('value').presence&.dig('name')
  end

  def insert_name_into_variant(content)
    content.gsub!('.:name:.', name_variable.presence || 'Participant')
  end

  def insert_variables_into_variant(content)
    insert_name_into_variant(content)

    user_intervention_answer_vars.each do |variable, value|
      content.gsub!(".:#{variable}:.", value.present? ? value.to_s : 'Unknown')
    end
    content
  end

  def user_intervention_service
    @user_intervention_service ||= V1::UserInterventionService.new(user_session.user_id, user_session.session.intervention_id, user_session.id)
  end

  def user_intervention_answer_vars
    user_intervention_service.var_values
  end

  def number_days
    {
      'once_a_day' => 1,
      'once_a_week' => 7,
      'once_a_month' => 30
    }
  end

  def send_sms(start_time, content)
    SmsPlans::SendSmsJob.set(wait_until: start_time).perform_later(user.phone.full_number, content, user.id)
  end

  def send_alert(start_time, content, phone)
    SmsPlans::SendSmsJob.set(wait_until: start_time).perform_later(phone.full_number, content, phone.user&.id, true)
  end

  def user_email(user)
    user.email.presence unless user.role?('guest')
  end

  def phone
    @phone ||= user.phone
  end

  def user
    @user ||= user_session.user
  end

  def now_in_timezone
    @now_in_timezone ||=
      begin
        timezone = Phonelib.parse(phone.full_number).timezone
        Time.use_zone(timezone) { Time.current }
      end
  end
end
