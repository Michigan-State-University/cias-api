# frozen_string_literal: true

FactoryBot.define do
  factory :organization_invitation do
    organization_id { create(:organization).id }
    user_id { create(:user, :confirmed, :researcher).id }

    trait :accepted do
      accepted_at { 2.days.ago }
    end
  end
end
