# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:first_name) { |s| "first_name_#{s}" }
    sequence(:last_name) { |s| "last_name_#{s}" }
    sequence(:email) { |s| "email_#{s}@#{ENV['DOMAIN_NAME']}" }
    sequence(:password) { |s| "GcAbAijoW_#{s}" }
    provider { 'email' }
    roles { %w[guest] }
    time_zone { 'Europe/Warsaw' }

    transient do
      allow_unconfirmed_period { Time.current - Devise.allow_unconfirmed_access_for }
    end

    trait :confirmed do
      after(:create, &:confirm)
    end

    trait :admin do
      roles { %w[admin] }
    end

    trait :guest do
      roles { %w[guest] }
    end

    trait :participant do
      roles { %w[participant] }
    end

    trait :researcher do
      roles { %w[researcher] }
    end

    trait :team_admin do
      roles { %w[team_admin] }
      team_id { create(:team).id }
    end

    trait :preview_session do
      roles { %w[preview_session] }
      after(:build) do |user, evaluator|
        user.preview_session_id = evaluator.preview_session_id
      end
    end

    trait :unconfirmed do
      after(:create) do |user, evaluator|
        user.update_attribute(:confirmation_sent_at, evaluator.allow_unconfirmed_period - 1.day)
      end
    end
  end
end
