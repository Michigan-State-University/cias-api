# frozen_string_literal: true

FactoryBot.define do
  factory :chart_statistic do
    sequence(:label) { |s| "label_#{s}" }
    association(:organization)
    association(:user_session)
    association(:health_system)
    association(:health_clinic)
    association(:chart)

    after(:build) do |chart_statistic|
      chart_statistic.user ||= chart_statistic.user_session&.user
    end
  end
end
