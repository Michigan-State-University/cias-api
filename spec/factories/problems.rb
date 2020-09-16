# frozen_string_literal: true

FactoryBot.define do
  factory :problem do
    user
    name { 'Problem' }
    trait :published do
      status { 'published' }
    end
    trait :closed do
      status { 'closed' }
    end
    trait :archived do
      status { 'archived' }
    end
    shared_to { 'anyone' }
  end
end
