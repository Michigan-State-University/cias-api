# frozen_string_literal: true

FactoryBot.define do
  factory :answer do
    user
    body do
      { data: [
        {
          payload: '',
          variable: {
            name: 'test',
            value: '1'
          }
        }
      ] }
    end
    factory :answer_analogue_scale do
      type { Answer::AnalogueScale }
      association :question, factory: :question_analogue_scale
      trait :wrong_type do
        association :question, factory: :question_multiple
      end
    end
    factory :answer_bar_graph do
      type { Answer::BarGraph }
      association :question, factory: :question_bar_graph
      trait :wrong_type do
        association :question, factory: :question_multiple
      end
    end
    factory :answer_feedback do
      type { Answer::Feedback }
      association :question, factory: :question_feedback
      trait :wrong_type do
        association :question, factory: :question_multiple
      end
    end
    factory :answer_follow_up_contact do
      type { Answer::FollowUpContact }
      association :question, factory: :question_follow_up_contact
      trait :wrong_type do
        association :question, factory: :question_multiple
      end
    end
    factory :answer_grid do
      type { Answer::Grid }
      association :question, factory: :question_grid
      trait :wrong_type do
        association :question, factory: :question_multiple
      end
    end
    factory :answer_multiple, class: 'Answer::Multiple' do
      type { Answer::Multiple }
      association :question, factory: :question_multiple
      trait :wrong_type do
        association :question, factory: :question_grid
      end
      trait :body_data_empty do
        body { { data: [] } }
      end
    end
    factory :answer_information do
      type { Answer::Information }
      association :question, factory: :question_information
      trait :wrong_type do
        association :question, factory: :question_multiple
      end
    end
    factory :answer_number do
      type { Answer::Number }
      association :question, factory: :question_number
      trait :wrong_type do
        association :question, factory: :question_multiple
      end
    end
    factory :answer_single, class: 'Answer::Single' do
      type { Answer::Single }
      association :question, factory: :question_single
      trait :wrong_type do
        association :question, factory: :question_multiple
      end
      trait :body_data_empty do
        body { { data: [] } }
      end
    end
    factory :answer_text_box, class: 'Answer::TextBox' do
      type { Answer::TextBox }
      association :question, factory: :question_text_box
      trait :wrong_type do
        association :question, factory: :question_multiple
      end
      trait :body_data_empty do
        body { { data: [] } }
      end
    end
    factory :answer_url do
      type { Answer::Url }
      association :question, factory: :question_url
      trait :wrong_type do
        association :question, factory: :question_multiple
      end
    end
  end
end
