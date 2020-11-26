# frozen_string_literal: true

FactoryBot.define do
  factory :session_invitation do
    association :session
    sequence(:email) { |s| "email_#{s}@session-invitation.example" }
  end
end
