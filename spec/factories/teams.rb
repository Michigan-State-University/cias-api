# frozen_string_literal: true

FactoryBot.define do
  factory :team do
    sequence(:name) { |n| "#{Faker::Team.name} #{n}" }
    team_admin { build(:user, :confirmed, :team_admin) }

    after(:build) do |team|
      team.team_admin.admins_teams = [team] unless team.team_admin.persisted?
    end
  end
end
