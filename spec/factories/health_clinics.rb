# frozen_string_literal: true

FactoryBot.define do
  factory :health_clinic do
    sequence(:name) { |n| "#{Faker::Alphanumeric.alpha(number: 6)} #{n}" }
    association(:health_system)

    trait :with_health_clinic_admin do
      after(:build) do |health_clinic|
        health_clinic_admin = create(:user, :confirmed, :health_clinic_admin)
        health_clinic_admin.organizable = health_clinic unless health_clinic_admin.organizable
        UserHealthClinic.create!(user: health_clinic_admin, health_clinic: health_clinic)
        HealthClinicInvitation.create!(user: health_clinic_admin, health_clinic: health_clinic, accepted_at: Time.now)
      end
    end
  end
end
