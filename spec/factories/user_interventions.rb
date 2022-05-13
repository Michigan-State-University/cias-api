# frozen_string_literal: true

FactoryBot.define do
  factory :user_intervention do
    association :user
    association :intervention

    trait :ready_to_start do
      status { 'ready_to_start' }
    end

    trait :in_progress do
      status { 'in_progress' }
    end

    trait :completed do
      status { 'completed' }
    end
  end
end
