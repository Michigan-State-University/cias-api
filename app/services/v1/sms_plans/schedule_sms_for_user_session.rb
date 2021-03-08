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
    return unless phone.present? && phone.confirmed?

    session.sms_plans.each do |plan|
      send("#{plan.schedule}_schedule", plan)
    end
  end

  private

  attr_reader :user_session

  def session
    @session ||= user_session.session
  end

  def after_session_end_schedule(plan)
    return if plan.is_used_formula || plan.no_formula_text.blank?

    set_frequency(Time.current, plan)
  end

  def days_after_session_end_schedule(plan)
    return if plan.is_used_formula || plan.no_formula_text.blank? || plan.schedule_payload.zero?

    start_time = now_in_timezone.next_day(plan.schedule_payload).change({ hour: 13 }).utc

    set_frequency(start_time, plan)
  end

  def set_frequency(start_time, plan)
    frequency = plan.frequency
    content = plan.no_formula_text
    finish_date = plan.end_at

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

  def number_days
    {
      'once_a_day' => 1,
      'once_a_week' => 7,
      'once_a_month' => 30
    }
  end

  def send_sms(start_time, content)
    SmsPlans::SendSmsJob.set(wait_until: start_time).perform_later(phone_number, content)
  end

  def phone
    @phone ||= user_session.user.phone
  end

  def now_in_timezone
    @now_in_timezone ||= begin
                           timezone = Phonelib.parse(phone_number).timezone
                           Time.use_zone(timezone) { Time.current }
                         end
  end

  def phone_number
    phone.prefix + phone.number
  end
end
