# frozen_string_literal: true

class V1::SmsPlans::ReScheduleSmsForUserSession
  include Rails.application.routes.url_helpers

  def self.call(user_session)
    new(user_session).call
  end

  def initialize(user_session)
    @user_session = user_session
    @user = user_session.user
  end

  attr_reader :user_session, :user

  def call
    return unless user.sms_notification
    return unless phone.present? && phone.confirmed?

    session.sms_plans.limit_to_types('SmsPlan::Normal').each do |plan|
      next unless can_run_plan?(plan)

      send("#{plan.schedule}_schedule", plan)
    end
  end

  private

  def after_session_end_schedule(plan)
    set_frequency(then_in_timezone, plan, true)
  end

  def days_after_session_end_schedule(plan)
    return after_session_end_schedule(plan) if plan.schedule_payload.zero?

    start_time = then_in_timezone.next_day(plan.schedule_payload).change(random_time).utc
    set_frequency(start_time, plan)
  end

  def then_in_timezone
    @then_in_timezone ||= Time.use_zone(timezone) { user_session.finished_at }
  end

  def paused_at
    intervention.paused_at
  end

  def set_frequency(start_time, plan, send_first_right_after_finish = false)
    frequency = plan.frequency
    content = sms_content(plan)
    return if content.blank?

    attachment_url = attachment_url(plan)
    content = insert_variables_into_variant(content)
    finish_date = plan.end_at

    if frequency == SmsPlan.frequencies[:once] && should_be_send?(start_time)
      send_sms(start_time, content, attachment_url)
    else

      if send_first_right_after_finish
        send_sms(start_time.utc, content, attachment_url) if should_be_send?(start_time)
        date = start_time.next_day(number_days[frequency])
      else
        date = start_time
      end

      while date.to_date <= finish_date.to_date
        send_sms(date.change(random_time).utc, content, attachment_url) if should_be_send?(date)
        date = date.next_day(number_days[frequency])
      end
    end
  end

  def should_be_send?(planed_time)
    planed_time.utc >= paused_at.utc
  end
end
