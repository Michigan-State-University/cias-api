# frozen_string_literal: true

FactoryBot.define do
  factory :health_system do
    sequence(:name) { |n| "#{Faker::Alphanumeric.alpha(number: 6)} #{n}" }
    organization { build(:organization) }

    trait :with_clinics do
      after(:create) do |health_system|
        health_system.health_clinics << create(:health_clinic)
      end
    end
  end
end
