# frozen_string_literal: true

FactoryBot.define do
  factory :problem do
    user
    name { 'Problem' }
    status { 'published' }
    shared_to { 'anyone' }
  end
end
