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
    association :question_group
  end

  factory :question_slider, class: Question::Slider do
    title { 'Slider' }
    type { Question::Slider }
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
        variable: {
          name: 'question_slider_var'
        }
      }
    end
    sequence(:position) { |s| s }
    association :question_group
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
    association :question_group
  end

  factory :question_feedback, class: Question::Feedback do
    title { 'Feedback' }
    type { Question::Feedback }
    body do
      {
        data: [
          {
            payload: {
              start_value: '',
              end_value: '',
              target_value: ''
            },
            spectrum: {
              payload: '1',
              patterns: [
                {
                  match: '1',
                  target: ['1']
                }
              ]
            }
          }
        ]
      }
    end
    sequence(:position) { |s| s }
    association :question_group
  end

  factory :question_finish, class: Question::Finish do
    type { Question::Finish }
    body do
      {
        data: []
      }
    end
    association :question_group
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
          name: 'follow_up_contact_var'
        }
      }
    end
    sequence(:position) { |s| s }
    association :question_group
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
                    name: 'row1'
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
    association :question_group
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
    association :question_group
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
              name: 'answer_1',
              value: ''
            }
          },
          {
            payload: '',
            variable: {
              name: 'answer_2',
              value: ''
            }
          },
          {
            payload: '',
            variable: {
              name: 'answer_3',
              value: ''
            }
          },
          {
            payload: '',
            variable: {
              name: 'answer_4',
              value: ''
            }
          }
        ]
      }
    end
    sequence(:position) { |s| s }
    association :question_group

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
          name: 'number_var'
        }
      }
    end
    sequence(:position) { |s| s }
    association :question_group
  end

  factory :question_single, class: Question::Single do
    title { 'Single' }
    type { Question::Single }
    image { FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg') }
    body do
      {
        data: [
          {
            payload: '',
            value: '1'
          },
          {
            payload: 'example2',
            value: ''
          }
        ],
        variable: {
          name: 'single_var'
        }
      }
    end
    sequence(:position) { |s| s }
    association :question_group

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

    trait :branching_to_question do
      formulas do
        [
          {
            payload: 'a1',
            patterns: [
              {
                match: '=1',
                target: [{
                  id: '',
                  probability: '100',
                  type: 'Question::Single'
                }]
              }
            ]
          }
        ]
      end
      body do
        {
          data: [
            {
              value: '1',
              payload: ''
            },
            {
              value: '2',
              payload: ''
            }
          ],
          variable: {
            name: 'a1'
          }
        }
      end
    end

    trait :branching_to_session do
      formulas do
        [
          {
            payload: 'a1',
            patterns: [
              { match: '=2',
                target: [{
                  id: '',
                  type: 'Session'
                }] }
            ]
          }
        ]
      end
      body do
        {
          data: [
            {
              value: '1',
              payload: ''
            },
            {
              value: '2',
              payload: ''
            }
          ],
          variable: { name: 'a1' }
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
              text: [
                'Medicine is the science and practice of establishing the diagnosis, prognosis, treatment, and prevention of disease.',
                'Working together as an interdisciplinary team, many highly trained health professionals'
              ],
              sha256: %w[80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2
                         cff0c9ce9f8394e5a6797002a2150c9ce6b7b2b072ece4f6a67b93be25aa0046],
              audio_urls: %w[spec/factories/audio/80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2.mp3
                             spec/factories/audio/cff0c9ce9f8394e5a6797002a2150c9ce6b7b2b072ece4f6a67b93be25aa0046.mp3],
              type: 'Speech'
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

    trait :narrator_blocks_types_with_name_variable do
      narrator do
        {
          settings: {
            voice: true,
            animation: true
          },
          blocks: [
            {
              # rubocop:disable Layout/LineLength
              text: ['Medicine is the science and practice of establishing the diagnosis, prognosis, treatment, and prevention of disease.', 'Working together as an interdisciplinary team, many highly trained health professionals', '.:name:.'],
              sha256: %w[80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2 cff0c9ce9f8394e5a6797002a2150c9ce6b7b2b072ece4f6a67b93be25aa0046 80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2],
              audio_urls: ['spec/factories/audio/80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2.mp3', 'spec/factories/audio/cff0c9ce9f8394e5a6797002a2150c9ce6b7b2b072ece4f6a67b93be25aa0046.mp3', 'spec/factories/audio/80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2.mp3'],
              # rubocop:enable Layout/LineLength
              type: 'Speech'
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

  factory :question_free_response, class: Question::FreeResponse do
    title { 'Free Response' }
    type { Question::FreeResponse }
    body do
      {
        data: [
          {
            payload: ''
          }
        ],
        variable: {
          name: 'free_response_var'
        }
      }
    end
    sequence(:position) { |s| s }
    association :question_group

    trait :body_data_empty do
      body { { data: [] } }
    end
  end

  factory :question_external_link, class: Question::ExternalLink do
    title { 'External Link' }
    type { Question::ExternalLink }
    body do
      {
        data: [
          {
            payload: ''
          }
        ],
        variable: {
          name: 'external_link_var'
        }
      }
    end
    sequence(:position) { |s| s }
    association :question_group
  end

  factory :question_date, class: Question::Date do
    title { 'date' }
    type { Question::Date }
    body do
      {
        data: [
          {
            payload: ''
          }
        ],
        variable: {
          name: 'date_var'
        }
      }
    end
    sequence(:position) { |s| s }
    association :question_group

    trait :body_data_empty do
      body { { data: [] } }
    end
  end

  factory :question_phone, class: Question::Phone do
    title { 'Phone' }
    type { Question::Phone }
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
    association :question_group

    trait :body_data_empty do
      body { { data: [] } }
    end
  end

  factory :question_currency, class: Question::Currency do
    title { 'Currency' }
    type { Question::Currency }
    body do
      {
        data: [
          {
            payload: ''
          }
        ],
        variable: {
          name: 'currency_var'
        }
      }
    end
    sequence(:position) { |s| s }
    association :question_group

    trait :body_data_empty do
      body { { data: [] } }
    end
  end

  factory :question_name, class: Question::Name do
    title { 'Name screen' }
    type { Question::Name }
    body do
      {
        data: [
          {
            payload: ''
          }
        ],
        variable: {
          name: '.:name:.'
        }
      }
    end
    sequence(:position) { |s| s }
    association :question_group

    trait :body_data_empty do
      body { { data: [] } }
    end
  end

  factory :question_participant_report, class: Question::ParticipantReport do
    title { 'ParticipantReport' }
    type { Question::ParticipantReport }
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
    association :question_group

    trait :body_data_empty do
      body { { data: [] } }
    end
  end

  factory :question_third_party, class: Question::ThirdParty do
    title { 'Third party' }
    type { Question::ThirdParty }
    body do
      {
        data: [
          {
            payload: '',
            value: '',
            report_template_ids: []
          }
        ]
      }
    end
    sequence(:position) { |s| s }
    association :question_group

    trait :body_data_empty do
      body { { data: [] } }
    end
  end

  factory :question_tlfb_config, class: Question::TlfbConfig do
    title { 'TlfbConfig' }
    type { Question::TlfbConfig }
    body do
      {
        data: [
          {
            payload: {
              days_count: '1',
              start_date: (DateTime.now - 1.day).to_s,
              end_date: DateTime.now,
              choose_date_range: false,
              display_helping_materials: false
            }
          }
        ]
      }
    end
    sequence(:position) { |s| s }
    association :question_group
  end

  factory :question_tlfb_event, class: Question::TlfbEvents do
    title { 'TlfbEvents' }
    type { Question::TlfbEvents }
    body do
      {
        data: [
          {
            payload:
              {
                screen_title: '',
                screen_question: ''
              }
          }
        ]
      }
    end
    sequence(:position) { |s| s }
    association :question_group
  end

  factory :question_tlfb_question, class: Question::TlfbQuestion do
    title { 'TlfbQuestion' }
    type { Question::TlfbQuestion }
    body do
      {
        data: [
          {
            payload:
              {
                question_title: '',
                head_question: '',
                substance_question: '',
                substances_with_group: true,
                substances: []
              }
          }
        ]
      }
    end
    sequence(:position) { |s| s }
    association :question_group
  end

  factory :question_henry_ford, class: Question::HenryFord do
    title { 'HenryFord' }
    type { Question::HenryFord }
    body do
      {
        data: [
          {
            payload: 'Never',
            value: 'Never',
            hfh_value: 'hfh1'
          },
          {
            payload: 'Monthly or less',
            value: 'Monthly or less',
            hfh_value: 'hfh2'
          }
        ],
        variable: {
          name: 'AUDIT_1'
        }
      }
    end
  end
end
