# frozen_string_literal: true

FactoryBot.define do
  factory :reporting_dashboard do
    association(:organization)
  end
end
