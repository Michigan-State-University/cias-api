# frozen_string_literal: true

FactoryBot.define do
  factory :session_invitation, class: Invitation do
    association :invitable, factory: :session
    sequence(:email) { |s| "email_#{s}@session-invitation.example" }
  end
end
