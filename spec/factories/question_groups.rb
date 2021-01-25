# frozen_string_literal: true

FactoryBot.define do
  factory :question_group do
    title { Faker::Name.name }
    association(:session)
    factory :question_group_plain, class: QuestionGroup::Plain do
    end
    factory :question_group_finish, class: QuestionGroup::Finish do
    end
  end
end
