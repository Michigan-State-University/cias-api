# frozen_string_literal: true

FactoryBot.define do
  factory :intervention_access, class: InterventionAccess do
    association :intervention, factory: :intervention
    sequence(:email) { |s| "email_#{s}@session-invitation.example" }
  end
end
