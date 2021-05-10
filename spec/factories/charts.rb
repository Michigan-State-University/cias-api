# frozen_string_literal: true

FactoryBot.define do
  factory :chart do
    sequence(:name) { |s| "chart_#{s}" }
    description { 'This is description' }
    association(:dashboard_section)
  end
end
