# frozen_string_literal: true

FactoryBot.define do
  factory :phone do
    user
    iso { 'US' }
    prefix { '+1' }
    sequence(:number) { |s| "20155501#{format('%02d', s % 100)}" }
    confirmation_code { '11111' }
    trait :unconfirmed do
      confirmed { false }
    end

    trait :confirmed do
      confirmed { true }
    end
  end
end
