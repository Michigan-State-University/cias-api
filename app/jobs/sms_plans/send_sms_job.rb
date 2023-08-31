# frozen_string_literal: true

class SmsPlans::SendSmsJob < ApplicationJob
  queue_as :sms_plans

  def perform(number, content, attachment_url, user_id, is_alert = false, user_session_id = nil)
    unless is_alert
      user = User.find(user_id)
      return unless user&.sms_notification
    end

    sms = Message.create(phone: number, body: content, attachment_url: attachment_url)
    Communication::Sms.new(sms.id).send_message
  end
end
