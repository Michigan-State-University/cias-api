# frozen_string_literal: true

FactoryBot.define do
  factory :user_intervention do
    association :user
    association :intervention
  end
end
