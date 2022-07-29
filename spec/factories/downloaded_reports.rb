# frozen_string_literal: true

FactoryBot.define do
  factory :downloaded_report do
    association(:generated_report)
    association(:user)
  end
end
