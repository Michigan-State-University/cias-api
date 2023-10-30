# frozen_string_literal: true

class V1::Users::SmsTokens::Send
  def self.call(user, phone_params)
    new(user, phone_params).call
  end

  def initialize(user, phone_params)
    @phone = V1::Users::SmsTokens::Phone.new(user, phone_params[:phone_number], phone_params[:iso], phone_params[:prefix]).phone
    @user = user
  end

  def call
    return unless phone

    phone.refresh_confirmation_code
    sms = Message.create(
      phone: number,
      body: I18n.with_locale(user.language_code) do
        I18n.t('phone_verification', verification_code: phone.confirmation_code)
      end
    )
    service = Communication::Sms.new(sms.id)
    service.send_message
    service
  end

  private

  attr_accessor :phone
  attr_reader :user

  def number
    phone.prefix + phone.number
  end
end
