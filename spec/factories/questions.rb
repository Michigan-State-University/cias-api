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
  end

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
    sequence(:position) { |s| s }
    association :intervention, factory: :intervention_single
  end

  factory :question_bar_graph, class: Question::BarGraph do
    title { 'Bar Graph' }
    type { Question::BarGraph }
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
  end

  factory :question_feedback, class: Question::Feedback do
    title { 'Feedback' }
    type { Question::Feedback }
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
  end

  factory :question_follow_up_contact, class: Question::FollowUpContact do
    title { 'Follow-up contact' }
    type { Question::FollowUpContact }
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
    sequence(:position) { |s| s }
    association :intervention, factory: :intervention_single
  end

  factory :question_information, class: Question::Information do
    title { 'Information' }
    type { Question::Information }
    body do
      {
        data: []
      }
    end
    sequence(:position) { |s| s }
    association :intervention, factory: :intervention_single
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
    sequence(:position) { |s| s }
    association :intervention, factory: :intervention_single

    trait :body_data_empty do
      body { { data: [] } }
    end
  end

  factory :question_number, class: Question::Number do
    title { 'Number' }
    type { Question::Number }
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
    sequence(:position) { |s| s }
    association :intervention, factory: :intervention_single
  end

  factory :question_single, class: Question::Single do
    title { 'Single' }
    type { Question::Single }
    image { Rack::Test::UploadedFile.new('spec/factories/images/test_image_1.jpg', 'image/jpeg') }
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

    trait :body_data_empty do
      body { { data: [] } }
    end

    trait :narrator_turn_off do
      narrator do
        {
          settings: {
            voice: false,
            animation: true
          },
          blocks: []
        }
      end
    end

    trait :narrator_blocks_empty do
      narrator do
        {
          settings: {
            voice: true,
            animation: true
          },
          blocks: []
        }
      end
    end

    trait :narrator_block_one do
      narrator do
        {
          settings: {
            voice: true,
            animation: true
          },
          blocks: [
            {
              text: ['Medicine is the science and practice of establishing the diagnosis, prognosis, treatment, and prevention of disease.'],
              type: 'Speech',
              sha256: ['80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2'],
              audio_urls: ['spec/factories/audio/80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2.mp3']
            }
          ]
        }
      end
    end

    trait :narrator_block_one_another_type do
      narrator do
        {
          settings: {
            voice: true,
            animation: true
          },
          blocks: [
            {
              text: [],
              type: 'BodyAnimation',
              sha256: [],
              audio_urls: []
            }
          ]
        }
      end
    end

    trait :narrator_blocks_types do
      narrator do
        {
          settings: {
            voice: true,
            animation: true
          },
          blocks: [
            {
              text: ['Medicine is the science and practice of establishing the diagnosis, prognosis, treatment, and prevention of disease.', 'Working together as an interdisciplinary team, many highly trained health professionals'],
              sha256: %w[80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2 cff0c9ce9f8394e5a6797002a2150c9ce6b7b2b072ece4f6a67b93be25aa0046],
              audio_urls: ['spec/factories/audio/80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2.mp3', 'spec/factories/audio/cff0c9ce9f8394e5a6797002a2150c9ce6b7b2b072ece4f6a67b93be25aa0046.mp3']
            },
            {
              text: [],
              type: 'BodyAnimation',
              sha256: [],
              audio_urls: []
            }
          ]
        }
      end
    end

    trait :narrator_blocks_with_speech_empty do
      narrator do
        {
          settings: {
            voice: true,
            animation: true
          },
          blocks: [
            {
              text: ['Working together as an interdisciplinary team, many highly trained health professionals'],
              sha256: ['cff0c9ce9f8394e5a6797002a2150c9ce6b7b2b072ece4f6a67b93be25aa0046'],
              audio_urls: ['spec/factories/audio/cff0c9ce9f8394e5a6797002a2150c9ce6b7b2b072ece4f6a67b93be25aa0046.mp3']
            },
            {
              text: [],
              type: 'Speech',
              sha256: [],
              audio_urls: []
            }
          ]
        }
      end
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
    sequence(:position) { |s| s }
    association :intervention, factory: :intervention_single

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
    sequence(:position) { |s| s }
    association :intervention, factory: :intervention_single
  end
end
