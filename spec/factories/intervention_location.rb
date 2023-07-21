# frozen_string_literal: true

FactoryBot.define do
  factory :intervention_location do
    intervention
    clinic_location
  end
end
