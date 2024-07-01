# frozen_string_literal: true

FactoryBot.define do
  factory :sms_code do
    sms_code { 'SMS_CODE' }
    association :session, factory: :sms_session
  end
end
