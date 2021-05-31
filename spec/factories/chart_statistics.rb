# frozen_string_literal: true

FactoryBot.define do
  factory :chart_statistic do
    sequence(:label) { |s| "label_#{s}" }
    association(:organization)
    association(:user)
    association(:health_system)
    association(:health_clinic)
    association(:chart)
  end
end
