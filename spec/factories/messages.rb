# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    phone { '+48111222333' }

    trait :with_code do
      body { 'Your CIAS verification code is: 1111' }
    end
  end
end
