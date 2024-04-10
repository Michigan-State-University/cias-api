# frozen_string_literal: true

FactoryBot.define do
  narrator_default_settings = {
    voice: true,
    animation: true,
    character: 'peedy'
  }

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
    settings do
      {
        image: false,
        narrator_skippable: false,
        proceed_button: true,
        required: true,
        start_autofinish_timer: false,
        subtitle: true,
        title: true,
        video: false
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
              range_start: 0,
              range_end: 100,
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
    settings do
      {
        image: false,
        narrator_skippable: false,
        proceed_button: true,
        required: true,
        start_autofinish_timer: false,
        subtitle: true,
        title: true,
        video: false
      }
    end

    trait :start_autofinish_timer_on do
      settings do
        {
          image: false,
          narrator_skippable: false,
          proceed_button: true,
          required: true,
          start_autofinish_timer: true,
          subtitle: true,
          title: true,
          video: false
        }
      end
    end

    trait :body_data_empty do
      body { { data: [] } }
    end

    trait :narrator_turn_off do
      narrator do
        {
          settings: {
            voice: false,
            animation: true,
            character: 'peedy'
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
          settings: narrator_default_settings,
          blocks: []
        }
      end
    end

    trait :narrator_block_one do
      narrator do
        {
          settings: narrator_default_settings,
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

    trait :read_question_block do
      narrator do
        {
          settings: narrator_default_settings,
          blocks: [
            {
              type: 'ReadQuestion',
              text: ['Medicine is the science and practice of establishing the diagnosis, prognosis, treatment, and prevention of disease.'],
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
          settings: narrator_default_settings,
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
          settings: narrator_default_settings,
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
          settings: narrator_default_settings,
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

    trait :narrator_blocks_with_cases do
      narrator do
        {
          settings: narrator_default_settings,
          blocks: [
            {
              type: 'Speech',
              text: ['Working together as an interdisciplinary team, many highly trained health professionals'],
              sha256: ['cff0c9ce9f8394e5a6797002a2150c9ce6b7b2b072ece4f6a67b93be25aa0046'],
              audio_urls: ['spec/factories/audio/cff0c9ce9f8394e5a6797002a2150c9ce6b7b2b072ece4f6a67b93be25aa0046.mp3']
            },
            {
              type: 'ReflectionFormula',
              payload: '1',
              reflections: [
                match: '=1',
                sha256: ['cff0c9ce9f8394e5a6797002a2150c9ce6b7b2b072ece4f6a67b93be25aa0046'],
                audio_urls: ['spec/factories/audio/cff0c9ce9f8394e5a6797002a2150c9ce6b7b2b072ece4f6a67b93be25aa0046.mp3'],
                text: ['Working together as an interdisciplinary team, many highly trained health professionals']
              ]
            }
          ]
        }
      end
    end

    trait :narrator_blocks_with_speech_empty do
      narrator do
        {
          settings: narrator_default_settings,
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

  factory :question_sms, class: Question::Sms do
    title { 'Sms screen' }
    type { Question::Sms }
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
          name: 'sms_var'
        }
      }
    end
    sms_schedule do
      {
        period: 'weekly',
        day_of_period: '1', # Monday
        time: {
          exact: '8:00 AM'
        }
      }
    end
    sequence(:position) { |s| s }
    association :question_group, factory: :sms_question_group

    trait :body_data_empty do
      body { { data: [] } }
    end
  end

  factory :question_sms_information, class: Question::SmsInformation do
    title { 'Name screen' }
    type { Question::SmsInformation }
    body do
      {
        data: []
      }
    end
    sms_schedule do
      {
        period: 'weekly',
        day_of_period: '1', # Monday
        time: {
          exact: '8:00 AM'
        }
      }
    end
    sequence(:position) { |s| s }
    association :question_group, factory: :sms_question_group

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
        ],
        variable: { name: '' }
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
                screen_title: 'Hello',
                screen_question: 'Did you drink alcohol today?'
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
                question_title: 'Questions',
                head_question: 'Test question',
                substance_question: 'Test substance question',
                substances_with_group: true,
                substances: []
              }
          }
        ]
      }
    end
    sequence(:position) { |s| s }
    association :question_group

    trait :with_substances do
      body do
        {
          data: [
            {
              payload:
                {
                  question_title: 'Questions',
                  head_question: 'Test question',
                  substance_question: 'Test substance question',
                  substances_with_group: false,
                  substances: [{ 'name' => 'Gin', 'variable' => 'gin' }, { 'name' => 'Wine', 'variable' => 'wine' }]
                }
            }
          ]
        }
      end
    end

    trait :with_substance_groups do
      body do
        {
          data: [
            {
              payload:
                {
                  question_title: 'Questions',
                  head_question: 'Test question',
                  substance_question: 'Test substance question',
                  substances_with_group: true,
                  substance_groups: [
                    { 'name' => 'Smokers group', 'substances' => [
                      { 'name' => 'cigarettes', 'unit' => 'cigs', 'variable' => 'cigarettes' },
                      { 'name' => 'cannabis', 'unit' => 'grams', 'variable' => 'cannabis' }
                    ] },
                    { 'name' => 'Alcohol group', 'substances' => [
                      { 'name' => 'Vodka', 'unit' => 'shots', 'variable' => 'vodka' },
                      { 'name' => 'Beer', 'unit' => 'cups', 'variable' => 'beer' }
                    ] }
                  ]
                }
            }
          ]
        }
      end
    end
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

    sequence(:position) { |s| s }
    association :question_group
  end

  factory :question_henry_ford_initial_screen, class: Question::HenryFordInitial do
    title { 'Question::HenryFordInitial' }
    type { Question::HenryFordInitial }
    body do
      {
        data: []
      }
    end
    sequence(:position) { |s| s }
    association :question_group
  end
end
