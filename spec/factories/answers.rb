# frozen_string_literal: true

FactoryBot.define do
  factory :answer do
    user_session
    body do
      { data: [
        {
          var: 'test',
          value: '1'
        }
      ] }
    end
    trait :wrong_type do
      association :question, factory: :question_multiple
    end
    trait :body_data_empty do
      body { { data: [] } }
    end
    factory :answer_slider do
      type { Answer::Slider }
      association :question, factory: :question_slider
    end
    factory :answer_bar_graph do
      type { Answer::BarGraph }
      association :question, factory: :question_bar_graph
    end
    factory :answer_feedback do
      type { Answer::Feedback }
      association :question, factory: :question_feedback
    end
    factory :answer_follow_up_contact do
      type { Answer::FollowUpContact }
      association :question, factory: :question_follow_up_contact
    end
    factory :answer_grid do
      type { Answer::Grid }
      association :question, factory: :question_grid
    end
    factory :answer_multiple, class: Answer::Multiple do
      type { Answer::Multiple }
      association :question, factory: :question_multiple
      trait :wrong_type do
        association :question, factory: :question_grid
      end
    end
    factory :answer_information do
      type { Answer::Information }
      association :question, factory: :question_information
    end
    factory :answer_number do
      type { Answer::Number }
      association :question, factory: :question_number
    end
    factory :answer_single, class: Answer::Single do
      type { Answer::Single }
      association :question, factory: :question_single
    end
    factory :answer_free_response, class: Answer::FreeResponse do
      type { Answer::FreeResponse }
      association :question, factory: :question_free_response
    end
    factory :answer_external_link do
      type { Answer::ExternalLink }
      association :question, factory: :question_external_link
    end
    factory :answer_currency do
      type { Answer::Currency }
      association :question, factory: :question_currency
    end
    factory :answer_phone do
      type { Answer::Phone }
      association :question, factory: :question_phone
    end
    factory :answer_date, class: Answer::Date do
      type { Answer::Date }
      association :question, factory: :question_date
    end
    factory :answer_name, class: Answer::Name do
      type { Answer::Name }
      association :question, factory: :question_name
    end
    factory :answer_participant_report, class: Answer::ParticipantReport do
      type { Answer::ParticipantReport }
      association :question, factory: :question_participant_report
    end
    factory :answer_third_party, class: Answer::ThirdParty do
      type { Answer::ThirdParty }
      association :question, factory: :question_third_party
    end
    factory :answer_cat_mh, class: Answer::CatMh do
      type { Answer::CatMh }
    end
    factory :answer_henry_ford, class: Answer::HenryFord do
      type { Answer::HenryFord }
      association :question, factory: :question_henry_ford
    end
  end
end
