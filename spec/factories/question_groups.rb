# frozen_string_literal: true

FactoryBot.define do
  factory :question_group do
    title { Faker::Name.name }
    association(:session)
    factory :question_group_plain, class: QuestionGroup::Plain do
    end
    factory :question_group_finish, class: QuestionGroup::Finish do
    end
    factory :tlfb_group, class: QuestionGroup::Tlfb do
      title { 'TLFB Study Group' }

      after(:build) do |question_group|
        question_group.questions << create(:question_tlfb_config, position: 1)
        question_group.questions << create(:question_tlfb_event, position: 2)
        question_group.questions << create(:question_tlfb_question, position: 3)
      end
    end
  end

  factory :sms_question_group, class: QuestionGroup do
    title { Faker::Name.name }
    association(:session, factory: :sms_session)
    factory :question_group_initial, class: QuestionGroup::Initial do
    end
  end
end
