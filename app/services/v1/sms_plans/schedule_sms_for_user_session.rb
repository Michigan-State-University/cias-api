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
    return if plan.is_used_formula.present? || plan.no_formula_text.blank?

    SmsPlans::SendSmsJob.perform_later(phone_number, plan.no_formula_text)
  end

  def phone
    @phone ||= user_session.user.phone
  end

  def phone_number
    phone.prefix + phone.number
  end
end
