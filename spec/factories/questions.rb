# frozen_string_literal: true

FactoryBot.define do
  factory :question do
    body do
      {
        data: [
          {
            payload: '',
            value: ''
          },
          {
            payload: 'example2',
            value: ''
          }
        ],
        variable: {
          name: ''
        }
      }
    end
    sequence(:position) { |s| s }
    association :intervention, factory: :intervention_single
    factory :question_analogue_scale, class: Question::AnalogueScale do
      title { 'Analogue Scale' }
      type { Question::AnalogueScale }
      body do
        {
          data: [
            {
              payload: {
                start_value: 'start',
                end_value: 'end'
              }
            }
          ],
          "variable": {
            "name": 'var_1'
          }
        }
      end
    end
    factory :question_bar_graph, class: Question::BarGraph do
      title { 'Bar Graph' }
      type { Question::BarGraph }
    end
    factory :question_feedback, class: Question::Feedback do
      title { 'Feedback' }
      type { Question::Feedback }
    end
    factory :question_follow_up_contact, class: Question::FollowUpContact do
      title { 'Follow-up contact' }
      type { Question::FollowUpContact }
    end
    factory :question_grid, class: Question::Grid do
      title { 'Grid' }
      type { Question::Grid }
      body do
        {
          data: [
            {
              payload: {
                rows: [
                  {
                    payload: '',
                    variable: {
                      name: ''
                    }
                  }
                ],
                columns: [
                  {
                    payload: '',
                    variable: {
                      value: '1'
                    }
                  },
                  {
                    payload: '',
                    variable: {
                      value: '1'
                    }
                  }
                ]
              }
            }
          ]
        }
      end
    end
    factory :question_information, class: Question::Information do
      title { 'Information' }
      type { Question::Information }
      body do
        {
          data: []
        }
      end
    end
    factory :question_multiple, class: Question::Multiple do
      title { 'Multiple' }
      type { Question::Multiple }
      body do
        {
          data: [
            {
              payload: '',
              variable: {
                name: '',
                value: ''
              }
            },
            {
              payload: '',
              variable: {
                name: '',
                value: ''
              }
            },
            {
              payload: '',
              variable: {
                name: '',
                value: ''
              }
            },
            {
              payload: '',
              variable: {
                name: '',
                value: ''
              }
            }
          ]
        }
      end
      trait :body_data_empty do
        body { { data: [] } }
      end
    end
    factory :question_number, class: Question::Number do
      title { 'Number' }
      body do
        {
          data: [
            {
              payload: ''
            }
          ],
          variable: {
            name: ''
          }
        }
      end
      type { Question::Number }
    end
    factory :question_single, class: Question::Single do
      title { 'Single' }
      type { Question::Single }
      image { Rack::Test::UploadedFile.new('spec/factories/images/test_image_1.jpg', 'image/jpeg') }
      trait :body_data_empty do
        body { { data: [] } }
      end
    end
    factory :question_text_box, class: Question::TextBox do
      title { 'TextBox' }
      type { Question::TextBox }
      body do
        {
          data: [
            {
              payload: ''
            }
          ],
          variable: {
            name: ''
          }
        }
      end
      trait :body_data_empty do
        body { { data: [] } }
      end
    end
    factory :question_url, class: Question::Url do
      title { 'Url' }
      type { Question::Url }
      body do
        {
          data: [
            {
              payload: ''
            }
          ],
          variable: {
            name: ''
          }
        }
      end
    end
  end
end
