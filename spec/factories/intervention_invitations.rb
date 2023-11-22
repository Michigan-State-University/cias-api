# frozen_string_literal: true

FactoryBot.define do
  factory :intervention_invitation, class: Invitation do
    association :invitable, factory: :intervention
    sequence(:email) { |s| "email_#{s}@intervention-invitation.example" }
  end
end
