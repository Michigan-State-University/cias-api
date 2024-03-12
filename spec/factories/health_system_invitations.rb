# frozen_string_literal: true

FactoryBot.define do
  factory :health_system_invitation do
    health_system_id { create(:health_system).id }
    user_id { create(:user, :confirmed, :health_system_admin).id }

    trait :accepted do
      accepted_at { 2.days.ago }
    end
  end
end
