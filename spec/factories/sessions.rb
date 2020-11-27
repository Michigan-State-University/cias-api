# frozen_string_literal: true

FactoryBot.define do
  factory :session do
    sequence(:name) { |s| "session_#{s}" }
    sequence(:position) { |s| s }
    association :intervention

    trait :with_questions do
      question { create_list(:question, 5) }
    end

    trait :with_answers do
      answers { create_list(:answer, 5) }
    end

    trait :days_after do
      schedule { 'days_after' }
      schedule_payload { 7 }
    end

    trait :days_after_fill do
      schedule { 'days_after_fill' }
    end

    trait :exact_date do
      schedule { 'exact_date' }
      schedule_at { Date.current + 7 }
    end
  end
end
