# frozen_string_literal: true

FactoryBot.define do
  factory :health_system do
    sequence(:name) { |n| "#{Faker::Alphanumeric.alpha(number: 6)} #{n}" }
    association(:organization)

    trait :with_health_system_admin do
      after(:build) do |health_system|
        health_system_admin = create(:user, :confirmed, :health_system_admin, organizable: health_system)
        health_system.health_system_admins << health_system_admin
      end
    end

    trait :with_health_clinic do
      after(:build) do |health_system|
        health_system.health_clinics << create(:health_clinic)
      end
    end
  end
end
