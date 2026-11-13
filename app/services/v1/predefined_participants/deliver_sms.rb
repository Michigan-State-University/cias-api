# frozen_string_literal: true

class V1::PredefinedParticipants::DeliverSms
  Result = Struct.new(:message, :error_code) do
    def sent? = error_code.nil?
  end

  def self.call(number, body, recipient_user_ids: nil)
    message = Message.create!(phone: number, body: body)
    sms = Communication::Sms.new(message, recipient_user_ids: recipient_user_ids)
    sms.send_message
    Result.new(message, sms.provider_error_code)
  end
end
