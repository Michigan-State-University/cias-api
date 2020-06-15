# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |s| "email_#{s}@#{ENV['DOMAIN_NAME']}" }
    sequence(:password) { |s| "GcAbAijoW_#{s}" }
    sequence(:username) { |s| "user_#{s}" }
    provider { 'email' }

    transient do
      allow_unconfirmed_period { Time.current - Devise.allow_unconfirmed_access_for }
    end

    trait :confirmed do
      after(:create, &:confirm)
    end

    trait :admin do
      roles { %w[admin] }
      sequence(:username) { |s| "admin_#{s}" }
    end

    trait :unconfirmed do
      after(:create) do |user, evaluator|
        user.update_attribute(:confirmation_sent_at, evaluator.allow_unconfirmed_period - 1.day)
      end
    end
  end
end
