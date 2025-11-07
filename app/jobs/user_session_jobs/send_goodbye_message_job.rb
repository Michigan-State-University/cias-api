# frozen_string_literal: true

class UserSessionJobs::SendGoodbyeMessageJob < ApplicationJob
  queue_as :question_sms

  def perform(user_session_id)
    user_session = UserSession.find_by(id: user_session_id)
    return unless user_session

    goodbye_message = user_session.session.completion_message
    return if goodbye_message.blank?

    user = user_session.user
    return unless user.sms_notification

    send_sms(user.full_number, goodbye_message)
  end

  private

  def send_sms(number, content)
    sms = Message.create(phone: number, body: content, attachment_url: nil)
    Communication::Sms.new(sms.id).send_message
  end
end
