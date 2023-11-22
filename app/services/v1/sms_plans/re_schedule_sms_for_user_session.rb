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

  def can_run_plan?(plan)
    return false if plan.is_used_formula.blank? && plan.no_formula_text.blank?
    return false if plan.is_used_formula && (plan.formula.blank? || plan.variants.empty?)

    true
  end

  def then_in_timezone
    @then_in_timezone ||= Time.use_zone(timezone) { intervention.paused_at }
  end

  def timezone
    timezone_defined_by_user = phone_answer&.migrated_body&.dig('data', 0, 'value', 'timezone').to_s
    ActiveSupport::TimeZone[timezone_defined_by_user].present? ? timezone_defined_by_user : Phonelib.parse(phone.full_number).timezone
  end

  def intervention
    @intervention ||= user_session.session.intervention
  end

  def phone_answer
    @phone_answer ||= user_session.answers.find_by(type: 'Answer::Phone')
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

  def sms_content(plan)
    plan.is_used_formula ? matched_variant(plan)&.content : plan.no_formula_text
  end

  def matched_variant(plan)
    all_var_values = V1::UserInterventionService.new(user_session.user_intervention_id, user_session.id).var_values
    V1::SmsPlans::CalculateMatchedVariant.call(plan.formula, plan.variants, all_var_values)
  end

  def attachment_url(plan)
    attachment = if plan.is_used_formula
                   matched_variant(plan).attachment
                 else
                   plan.no_formula_attachment
                 end
    url_for(attachment) if attachment.attached?
  end

  def insert_variables_into_variant(content)
    insert_name_into_variant(content)

    user_intervention_answer_vars.each do |variable, value|
      content.gsub!(".:#{variable}:.", value.present? ? value.to_s : 'Unknown')
    end
    content
  end

  def insert_name_into_variant(content)
    content.gsub!('.:name:.', name_variable.presence || 'Participant')
  end

  def user_intervention_answer_vars
    user_intervention_service.var_values
  end

  def user_intervention_service
    @user_intervention_service ||= V1::UserInterventionService.new(user_session.user_intervention_id, user_session.id)
  end
end
