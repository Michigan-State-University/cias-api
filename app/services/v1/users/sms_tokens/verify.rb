# frozen_string_literal: true

class V1::Users::SmsTokens::Verify
  def self.call(user, sms_token)
    new(user, sms_token).call
  end

  def initialize(user, sms_token)
    @phone = user.phone
    @sms_token = sms_token
  end

  def call
    return nil unless phone&.token_correct?(sms_token)

    phone.confirm!
    phone
  end

  private

  attr_reader :sms_token
  attr_accessor :phone
end
