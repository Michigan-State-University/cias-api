# frozen_string_literal: true

class SmsPlans::SendSmsJob < ApplicationJob
  queue_as :sms_plans

  def perform(number, content)
    sms = Message.create(phone: number, body: content)
    Communication::Sms.new(sms.id).send_message
  end
end
