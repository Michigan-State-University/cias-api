# frozen_string_literal: true

FactoryBot.define do
  factory :dashboard_section do
    sequence(:name) { |s| "dashboard_section_#{s}" }
    description { 'This is description' }
    association(:reporting_dashboard)
  end
end
