# frozen_string_literal: true

FactoryBot.define do
  factory :health_clinic_invitation do
    health_clinic_id { create(:health_clinic).id }
    user_id { create(:user, :confirmed, :health_clinic_admin).id }

    trait :accepted do
      accepted_at { Time.current - 2.days }
    end
  end
end
