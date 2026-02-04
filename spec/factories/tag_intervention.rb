# frozen_string_literal: true

FactoryBot.define do
  factory :tag_intervention do
    association :tag
    association :intervention
  end
end
