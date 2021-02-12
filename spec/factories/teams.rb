# frozen_string_literal: true

FactoryBot.define do
  factory :team do
    name { Faker::Team.name }

    trait :with_team_admin do
      after(:create) do |team|
        create(:user, :confirmed, :team_admin, team_id: team.id)
      end
    end
  end
end
