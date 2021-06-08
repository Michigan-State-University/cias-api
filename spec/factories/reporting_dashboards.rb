# frozen_string_literal: true

FactoryBot.define do
  factory :reporting_dashboard do
    association(:organization)

    trait :with_dashboard_section do
      after(:build) do |reporting_dashboard|
        reporting_dashboard.dashboard_sections << create(:dashboard_section)
      end
    end
  end
end
