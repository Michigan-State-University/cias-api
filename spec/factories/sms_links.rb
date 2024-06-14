# frozen_string_literal: true

FactoryBot.define do
  factory :sms_link, class: SmsLink do
    association(:session)
    association(:sms_plan)
    sequence(:url) { 'google.com' }
    sequence(:link_type) { 'website' }
    sequence(:variable_number) { 1 }
  end
end
