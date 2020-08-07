# frozen_string_literal: true

FactoryBot.define do
  factory :problem do
    user
    allow_guests { false }
    name { 'Problem' }
    status { 'published' }
  end
end
