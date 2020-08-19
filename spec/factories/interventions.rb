# frozen_string_literal: true

FactoryBot.define do
  factory :intervention do
    sequence(:name) { |s| "intervention_#{s}" }
    sequence(:position) { |s| s }
    association :problem
    trait :slug do
      name { 'Intervention' }
    end

    trait :with_questions do
      question { create_list(:question, 5) }
    end

    trait :with_answers do
      answers { create_list(:answer, 5) }
    end
  end
end
