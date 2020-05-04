# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |s| "email_#{s}@#{s}.com" }
    sequence(:password) { |s| Argon2::Password.create(s.to_s) }
  end
end
