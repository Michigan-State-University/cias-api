# frozen_string_literal: true

FactoryBot.define do
  factory :sms_links_user, class: SmsLinksUser do
    association(:sms_link)
    association(:user)
    sequence(:entered_timestamps) { [] }
  end
end
