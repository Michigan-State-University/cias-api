# frozen_string_literal: true

FactoryBot.define do
  factory :clinic_location do
    sequence(:department) { |s| "department_#{s}" }
    sequence(:name) { |s| "location_#{s}" }
  end
end
