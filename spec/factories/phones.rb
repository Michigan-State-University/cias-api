# frozen_string_literal: true

FactoryBot.define do
  factory :phone do
    user
    iso { 'PL' }
    prefix { '+48' }
    sequence(:number) { |s| "11122233#{s}" }
    confirmation_code { '11111' }
    trait :unconfirmed do
      confirmed { false }
    end

    trait :confirmed do
      confirmed { true }
    end
  end
end
