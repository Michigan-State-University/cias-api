# frozen_string_literal: true

class V1::SmsPlans::ScheduleSmsForUserSession
  include ::SmsHelper

  def self.call(user_session)
    new(user_session).call
  end

  def initialize(user_session)
    @user_session = user_session
  end

  def call
    return unless session.intervention.published?

    execute_plans_for('SmsPlan::Alert')

    return unless user.sms_notification
    return unless phone.present? && phone.confirmed?

    execute_plans_for('SmsPlan::Normal')
  end

  private

  attr_reader :user_session

  def execute_plans_for(type)
    session.sms_plans.limit_to_types(type).each do |plan|
      next unless can_run_plan?(plan)

      send("#{plan.schedule}_schedule", plan)
    end
  end

  def after_session_end_schedule(plan)
    current_time = if plan.is_a? SmsPlan::Alert
                     Time.current
                   else
                     now_in_timezone
                   end

    set_frequency(current_time, plan, true)
  end

  def days_after_session_end_schedule(plan)
    return after_session_end_schedule(plan) if plan.schedule_payload.zero?

    start_time = now_in_timezone.next_day(plan.schedule_payload).change(random_time).utc
    set_frequency(start_time, plan)
  end

  def set_frequency(start_time, plan, send_first_right_after_finish = false)
    frequency = plan.frequency
    content = sms_content(plan)
    return if content.blank?

    attachment_url = attachment_url(plan)
    content = insert_variables_into_variant(content)
    finish_date = plan.end_at

    if plan.alert?
      content = prepend_alert_content(content, plan)
      plan.phones.each { |phone| send_alert(start_time, content, phone, attachment_url) }
      return
    end

    if frequency == SmsPlan.frequencies[:once]
      send_sms(start_time, content, attachment_url)
    else

      if send_first_right_after_finish
        send_sms(start_time.utc, content, attachment_url)
        date = start_time.next_day(number_days[frequency])
      else
        date = start_time
      end

      while date.to_date <= finish_date.to_date
        send_sms(date.change(random_time).utc, content, attachment_url)
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

  def send_alert(start_time, content, phone, attachment_url = nil)
    SmsPlans::SendSmsJob.set(wait_until: start_time).perform_later(phone.full_number, content, attachment_url, phone.user&.id, true, user_session.session_id)
  end

  def user_email(user)
    user.email.presence unless user.role?('guest')
  end

  def now_in_timezone
    @now_in_timezone ||= Time.use_zone(timezone) { Time.current }
  end
end
