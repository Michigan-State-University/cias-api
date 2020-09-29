# frozen_string_literal: true

FactoryBot.define do
  factory :question_group do
    title { Faker::Name.name }

    association(:intervention)
  end
end
