# frozen_string_literal: true

class SmsPlans::SendSmsJob < ApplicationJob
  queue_as :sms_plans

  def perform(number, content, user_id)
    user = User.find(user_id)
    return unless user.sms_notification

    sms = Message.create(phone: number, body: content)
    Communication::Sms.new(sms.id).send_message
  end
end
