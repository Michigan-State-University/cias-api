# frozen_string_literal: true

FactoryBot.define do
  factory :organization do
    sequence(:name) { |s| "organization_#{s}" }
  end
end
