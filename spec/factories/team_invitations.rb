# frozen_string_literal: true

FactoryBot.define do
  factory :team_invitation do
    team_id { create(:team).id }
    user_id { create(:user, :confirmed, :researcher).id }

    trait :accepted do
      accepted_at { 2.days.ago }
    end
  end
end
