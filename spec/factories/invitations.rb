# frozen_string_literal: true

FactoryBot.define do
  factory :invitation do
    sequence(:email) { |s| "email_#{s}@#{ENV['DOMAIN_NAME']}" }
    invitable { build(:session) }
  end
end
