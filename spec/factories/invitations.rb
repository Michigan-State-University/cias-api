# frozen_string_literal: true

FactoryBot.define do
  factory :invitation do
    sequence(:email) { |s| "email_#{s}@#{ENV.fetch('DOMAIN_NAME', nil)}" }
    invitable { build(:session) }
  end
end
