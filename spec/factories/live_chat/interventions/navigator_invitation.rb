# frozen_string_literal: true

FactoryBot.define do
  factory :navigator_invitation, class: LiveChat::Interventions::NavigatorInvitation do
    association(:intervention)
    sequence(:email) { |s| "email_#{s}@#{ENV.fetch('DOMAIN_NAME', nil)}" }

    trait :confirmed do
      accepted_at { DateTime.now }
    end
  end
end
