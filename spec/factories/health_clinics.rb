# frozen_string_literal: true

FactoryBot.define do
  factory :health_clinic do
    sequence(:name) { |n| "#{Faker::Alphanumeric.alpha(number: 6)} #{n}" }
    health_system { build(:health_system) }
  end
end
