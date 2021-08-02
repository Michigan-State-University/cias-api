# frozen_string_literal: true

class V1::Users::SmsTokens::Send
  def self.call(user, phone_params)
    new(user, phone_params).call
  end

  def initialize(user, phone_params)
    @phone = V1::Users::SmsTokens::Phone.new(user, phone_params[:phone_number], phone_params[:iso], phone_params[:prefix]).phone
  end

  def call
    return unless phone

    phone.refresh_confirmation_code
    sms = Message.create(
      phone: number,
      body: "Your CIAS verification code is: #{phone.confirmation_code}"
    )
    service = Communication::Sms.new(sms.id)
    service.send_message
    service
  end

  private

  attr_accessor :phone

  def number
    phone.prefix + phone.number
  end
end
