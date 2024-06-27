# frozen_string_literal: true

class SmsPlans::SendSmsJob < ApplicationJob
  queue_as :sms_plans

  def perform(number, content, attachment_url, user_id, is_alert = false, _session_id = nil)
    unless is_alert
      user = User.find(user_id) if user_id
      return if user && !user.sms_notification
    end

    sms = Message.create(phone: number, body: content, attachment_url: attachment_url)
    Communication::Sms.new(sms.id).send_message
  end
end
