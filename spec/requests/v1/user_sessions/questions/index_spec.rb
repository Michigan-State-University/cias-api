# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/user_session/:user_session_id/question', type: :request do
  context 'UserSession::Classic' do
    let(:participant) { create(:user, :confirmed, :participant) }
    let(:researcher) { create(:user, :confirmed, :researcher) }
    let!(:intervention) { create(:intervention, user_id: researcher.id, status: status, license_type: 'unlimited') }
    let!(:session) { create(:session, intervention_id: intervention.id) }
    let!(:question_group) { create(:question_group, session: session) }
    let!(:question) { create(:question_single, question_group: question_group) }
    let(:audio_id) { nil }
    let(:user_int) { create(:user_intervention, intervention: intervention, user: user) }
    let!(:user_session) { create(:user_session, user_id: participant.id, session_id: session.id, name_audio_id: audio_id, user_intervention: user_int) }
    let!(:answer) { create(:answer_single, question_id: question.id, user_session_id: user_session.id) }
    let(:status) { 'draft' }
    let(:user) { participant }
    let(:default_narrator_settings) { { voice: true, animation: true, character: 'peedy' } }

    context 'when start immediately is set' do
      let!(:session2) { create(:session, intervention_id: intervention.id, schedule: :immediately) }
      let!(:question_group2) { create(:question_group, session: session2) }
      let!(:question2) { create(:question_single, question_group: question_group2) }
      let(:status) { 'published' }

      before do
        get v1_user_session_questions_url(user_session.id), headers: user.create_new_auth_token
      end

      it 'returns first question of session' do
        expect(json_response['data']['id']).to eq(question2.id)
      end

      it 'set session as finished' do
        expect(user_session.reload.finished_at).not_to be(nil)
      end
    end

    context 'tlfb logic' do
      let!(:tlfb_session) { create(:session, intervention_id: intervention.id) }
      let!(:tlfb_question_group) { create(:tlfb_group, session: tlfb_session) }
      let!(:tlfb_user_session) do
        create(:user_session, user_id: participant.id, session_id: tlfb_session.id, name_audio_id: audio_id, user_intervention: user_int)
      end

      before do
        get v1_user_session_questions_url(tlfb_user_session.id), headers: user.create_new_auth_token
      end

      it 'skip tlfbConfig and return tlfbEvent' do
        expect(json_response['data']['attributes']['type']).to eq('Question::TlfbEvents')
      end

      it 'return information that tlfbEvent is a first question instead of tlfbConfig' do
        expect(json_response['data']['attributes']['first_question']).to be(true)
      end
    end

    context 'user session has draft answer' do
      let!(:answer) { create(:answer_single, question_id: question.id, user_session_id: user_session.id, draft: true) }

      before do
        get v1_user_session_questions_url(user_session.id), headers: user.create_new_auth_token
      end

      it 'returns first question of session' do
        expect(json_response['data']['id']).to eq(question.id)
      end

      it 'return also draft answer in response' do
        expect(json_response['answer']['id']).to eq(answer.id)
      end
    end

    context 'branching logic' do
      before do
        get v1_user_session_questions_url(user_session.id), headers: user.create_new_auth_token
      end

      context 'response when finishing a session in fixed order intervention' do
        let(:session) { build(:session, position: 1) }
        let(:target_session) { build(:session, position: 2) }
        let!(:intervention) { create(:fixed_order_intervention, user: researcher, sessions: [session, target_session]) }
        let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
        let!(:user_session) { create(:user_session, session: session, user_id: user.id, user_intervention: user_intervention) }

        context 'returns next module id' do
          it { expect(json_response['next_session_id']).to eq(target_session.id) }
        end

        context 'returns nil or empty string when finishing last module' do
          let(:session) { build(:session, position: 1) }
          let!(:intervention) { create(:fixed_order_intervention, user: researcher, sessions: [session]) }

          it { expect(json_response['next_session_id']).to be_falsey }
        end
      end

      context 'response with question with calculated target_value' do
        let!(:question_with_reflection_formula) do
          question_single = build(:question_single, question_group: question_group, position: 2)
          question_single.narrator = {
            blocks: [
              {
                action: 'SHOW_USER_VALUE',
                payload: 'test',
                reflections: [
                  {
                    match: '=1',
                    text: [
                      'Good your value is 20.'
                    ],
                    audio_urls: [],
                    sha256: []
                  },
                  {
                    match: '=2',
                    text: [
                      'Bad.'
                    ],
                    audio_urls: [],
                    sha256: []
                  }
                ],
                animation: 'pointUp',
                type: 'ReflectionFormula',
                endPosition: {
                  x: 0,
                  y: 600
                }
              }
            ],
            settings: default_narrator_settings
          }
          question_single.save
          question_single
        end

        let!(:question) do
          question = build(:question_single, question_group: question_group, position: 1)
          question.formulas = [{ 'payload' => 'test',
                                 'patterns' => [
                                   {
                                     'match' => '=1',
                                     'target' => [{ 'id' => question_with_reflection_formula.id, 'probability' => '100',
                                                    'type' => 'Question' }]
                                   }
                                 ] }]
          question.body = { 'data' => [{ 'value' => '1', 'payload' => '' }, { 'value' => '2', 'payload' => '' }],
                            'variable' => { 'name' => 'test' } }
          question.save
          question
        end

        it { expect(json_response['data']['id']).to eq question_with_reflection_formula.id }

        it 'response contains target_value' do
          expect(json_response['data']['attributes']['narrator']['blocks'].first).to include(
            'target_value' => include('text' => ['Good your value is 20.'], 'match' => '=1')
          )
        end
      end

      context 'response with name mp3 override' do
        let(:audio) { create(:audio) }
        let(:audio_id) { audio.id }
        let!(:name_question) { create(:question_name, question_group: question_group, position: 1) }
        let!(:name_answer) do
          create(:answer_name, question: name_question, user_session: user_session, created_at: DateTime.now - 1.day,
                               updated_at: DateTime.now - 1.day, body: { data: [{ var: '.:name:.', value: { name: 'Michał', phonetic_name: 'Michał' } }] })
        end

        context 'for speech block' do
          let!(:question_with_speech_block) do
            create(:question_single, question_group: question_group, position: 3,
                                     narrator: {
                                       blocks: [
                                         {
                                           action: 'NO_ACTION',
                                           payload: 'test',
                                           audio_urls: ['invalid_url'],
                                           text: [':name:.'],
                                           sha256: ['some_sha'],
                                           animation: 'pointUp',
                                           type: 'Speech',
                                           endPosition: {
                                             x: 0,
                                             y: 600
                                           }
                                         }
                                       ],
                                       settings: default_narrator_settings
                                     })
          end
          let!(:question) { create(:question_single, question_group: question_group, position: 2) }

          before do
            allow_any_instance_of(Audio).to receive(:url).and_return('phonetic_audio.mp3')
            get v1_user_session_questions_path(user_session.id), headers: user.create_new_auth_token
          end

          it 'swaps url correctly' do
            expect(json_response['data']['attributes']['narrator']['blocks'].first['audio_urls'].first).to eq('phonetic_audio.mp3')
          end

          it 'swaps name correctly' do
            expect(json_response['data']['attributes']['narrator']['blocks'].first['text'].first).to eq('Michał')
          end
        end

        context 'for ReflectionFormula block' do
          let!(:question_with_reflection_formula) do
            create(:question_single, question_group: question_group, position: 3,
                                     narrator: {
                                       blocks: [
                                         {
                                           action: 'NO_ACTION',
                                           payload: 'test',
                                           reflections: [
                                             {
                                               match: '=1',
                                               text: [
                                                 'Good your value is 20.',
                                                 ':name:.'
                                               ],
                                               audio_urls: %w[
                                                 some_url
                                                 some_url2
                                               ],
                                               sha256: %w[
                                                 some_sha
                                                 some_sha2
                                               ]
                                             },
                                             {
                                               match: '=2',
                                               text: [
                                                 'Bad.'
                                               ],
                                               audio_urls: ['some_other_url'],
                                               sha256: ['sone_other_sha']
                                             }
                                           ],
                                           animation: 'pointUp',
                                           type: 'ReflectionFormula',
                                           endPosition: {
                                             x: 0,
                                             y: 600
                                           }
                                         }
                                       ],
                                       settings: default_narrator_settings
                                     })
          end

          let!(:question) { create(:question_single, question_group: question_group, position: 2) }

          before do
            allow_any_instance_of(Audio).to receive(:url).and_return('phonetic_audio.mp3')
            get v1_user_session_questions_path(user_session.id), headers: user.create_new_auth_token
          end

          it 'swaps url correctly' do
            expect(json_response['data']['attributes']['narrator']['blocks'].first['reflections'].first['audio_urls'].second)
              .to eq('phonetic_audio.mp3')
          end

          it 'swaps name correctly' do
            expect(json_response['data']['attributes']['narrator']['blocks'].first['reflections'].first['text'].second).to eq('Michał')
          end
        end

        context 'for reflection block' do
          let!(:question_with_reflection_formula) do
            create(:question_single, question_group: question_group, position: 3,
                                     narrator: {
                                       blocks: [
                                         {
                                           action: 'NO_ACTION',
                                           payload: 'test',
                                           reflections: [
                                             {
                                               payload: '1',
                                               value: '1',
                                               variable: 'test',
                                               text: [
                                                 ':name:.'
                                               ],
                                               audio_urls: [
                                                 'some_url2'
                                               ],
                                               sha256: [
                                                 'some_sha2'
                                               ]
                                             }
                                           ],
                                           animation: 'pointUp',
                                           type: 'Reflection',
                                           endPosition: {
                                             x: 0,
                                             y: 600
                                           }
                                         }
                                       ],
                                       settings: default_narrator_settings
                                     })
          end

          let!(:question) { create(:question_single, question_group: question_group, position: 2) }

          before do
            allow_any_instance_of(Audio).to receive(:url).and_return('phonetic_audio.mp3')
            get v1_user_session_questions_path(user_session.id), headers: user.create_new_auth_token
          end

          it 'swaps url correctly' do
            expect(json_response['data']['attributes']['narrator']['blocks'].first['reflections'].first['audio_urls'].first).to eq('phonetic_audio.mp3')
          end

          it 'swaps name correctly' do
            expect(json_response['data']['attributes']['narrator']['blocks'].first['reflections'].first['text'].first).to eq('Michał')
          end
        end
      end

      context 'modules intervention' do
        let!(:intervention) { create(:fixed_order_intervention, user_id: researcher.id, status: status) }
        let!(:session) { create(:session, intervention_id: intervention.id) }
        let!(:user_session) { create(:user_session, user_id: participant.id, session_id: session.id, name_audio_id: audio_id, user_intervention: user_int) }
        let!(:next_session) { create(:session, intervention_id: intervention.id) }
        let(:questions) { create_list(:question_single, 4, question_group: question_group) }
        let!(:question) do
          question = questions.first
          question.formulas = [{ 'payload' => 'test',
                                 'patterns' => [
                                   {
                                     'match' => '=1',
                                     'target' => [
                                       { 'id' => next_session.id, 'probability' => '100', 'type' => 'Session' }
                                     ]
                                   }
                                 ] }]
          question.save
          question
        end

        it 'returns next question' do
          expect(json_response['data']['id']).to eq questions[1].id
        end

        context 'with flexible order' do
          let!(:intervention) { create(:flexible_order_intervention, user_id: researcher.id, status: status) }
          let(:questions) { create_list(:question_single, 1, question_group: question_group) }

          it 'returns next question' do
            expect(json_response['data']['attributes']['type']).to eq 'Question::Finish'
          end
        end
      end
    end

    context 'user session does not have have answers' do
      let!(:other_session) { create(:user_session, session: session, user: other_user) }
      let!(:other_user) { create(:user, :participant, :confirmed) }

      before do
        get v1_user_session_questions_url(other_session.id), headers: other_user.create_new_auth_token
      end

      it 'returns first question of session' do
        expect(json_response['data']['id']).to eq(question.id)
      end
    end

    context 'start preview from given question' do
      before do
        get v1_user_session_questions_url(user_session.id), params: params, headers: user.create_new_auth_token
      end

      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let(:params) { { preview_question_id: questions[2].id } }

      context 'intervention is draft' do
        it 'returns correct question id' do
          expect(json_response['data']['id']).to eq questions[2].id
        end

        it 'return information that isn\'t first question' do
          expect(json_response['data']['attributes']['first_question']).to be(false)
        end
      end

      context 'intervention is published' do
        let(:status) { 'published' }

        it 'returns correct question id' do
          expect(json_response['data']['id']).to eq questions[0].id
        end
      end
    end

    context 'speech reflections' do
      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let(:question) { questions.first }

      before do
        get v1_user_session_questions_url(user_session.id), headers: user.create_new_auth_token
      end

      context 'reflection block' do
        context 'correctly setup' do
          let!(:question_second) do
            question = questions.second
            question.narrator = {
              blocks: [{
                type: 'Reflection',
                action: 'NO_ACTION',
                animation: 'rest',
                endPosition: {
                  x: 600,
                  y: 600
                },
                question_id: questions.first.id,
                reflections: [
                  {
                    text: [
                      'test'
                    ],
                    value: '1',
                    sha256: [],
                    payload: '1',
                    variable: 'test',
                    audio_urls: []
                  },
                  {
                    text: [
                      'test2'
                    ],
                    value: '2',
                    sha256: [],
                    payload: '2',
                    variable: 'test',
                    audio_urls: []
                  }
                ]
              }],
              settings: default_narrator_settings
            }
            question.save!
          end

          before do
            get v1_user_session_questions_url(user_session.id), headers: user.create_new_auth_token
          end

          it 'returns correct target value size' do
            expect(json_response['data']['attributes']['narrator']['blocks'].first['target_value'].size).to eq(1)
          end

          it 'has correct reflection text' do
            expect(json_response['data']['attributes']['narrator']['blocks'].first['target_value'].first['text'].first).to eq('test')
          end
        end

        context 'refection from another session' do
          let(:session2) { create(:session, intervention: intervention, name: 'dwa') }
          let!(:user_session2) { create(:user_session, session: session2, user_intervention: user_int) }
          let!(:question_group2) { create(:question_group, session: session2) }
          let!(:question2) { create(:question_single, question_group: question_group2) }
          let!(:answer2) { create(:answer_single, question_id: question2.id, user_session_id: user_session2.id) }
          let!(:questions) { create_list(:question_single, 4, question_group: question_group) }

          let!(:question_second) do
            question = questions.second
            question.narrator = {
              blocks: [{
                type: 'Reflection',
                action: 'NO_ACTION',
                animation: 'rest',
                endPosition: {
                  x: 600,
                  y: 600
                },
                question_id: question2.id,
                session_id: session2.id,
                question_group_id: question_group2.id,
                reflections: [
                  {
                    text: [
                      'test'
                    ],
                    value: '1',
                    sha256: [],
                    payload: '1',
                    variable: 'test',
                    audio_urls: []
                  },
                  {
                    text: [
                      'test2'
                    ],
                    value: '2',
                    sha256: [],
                    payload: '2',
                    variable: 'test',
                    audio_urls: []
                  }
                ]
              }],
              settings: default_narrator_settings
            }
            question.save!
          end

          before do
            get v1_user_session_questions_url(user_session.id), headers: user.create_new_auth_token
          end

          it 'returns correct target value size' do
            expect(json_response['data']['attributes']['narrator']['blocks'].first['target_value'].size).to eq(1)
          end

          it 'has correct reflection text' do
            expect(json_response['data']['attributes']['narrator']['blocks'].first['target_value'].first['text'].first).to eq('test')
          end
        end

        context 'incorrectly setup' do
          let!(:question_second) do
            question = questions.second
            question.narrator = {
              blocks: [{
                type: 'Reflection',
                action: 'NO_ACTION',
                animation: 'rest',
                endPosition: {
                  x: 600,
                  y: 600
                },
                question_id: questions.first.id,
                reflections: [
                  {
                    text: [
                      'test'
                    ],
                    value: '',
                    sha256: [],
                    payload: '',
                    variable: '',
                    audio_urls: []
                  },
                  {
                    text: [
                      'test2'
                    ],
                    value: '',
                    sha256: [],
                    payload: '',
                    variable: '',
                    audio_urls: []
                  }
                ]
              }],
              settings: default_narrator_settings
            }
            question.save!
          end

          context 'when intervention is draft' do
            before do
              get v1_user_session_questions_url(user_session.id), headers: user.create_new_auth_token
            end

            it 'returns correct target value size' do
              expect(json_response['data']['attributes']['narrator']['blocks'].first['target_value'].size).to eq(0)
            end

            it 'has correct warning' do
              expect(json_response['warning']).to eq('ReflectionMissMatch')
            end
          end

          context 'when intervention is published' do
            let(:status) { 'published' }

            before do
              get v1_user_session_questions_url(user_session.id), headers: user.create_new_auth_token
            end

            it 'returns correct target value size' do
              expect(json_response['data']['attributes']['narrator']['blocks'].first['target_value'].size).to eq(0)
            end

            it 'has correct warning' do
              expect(json_response['warning']).to eq(nil)
            end
          end
        end
      end

      context 'reflection formula block' do
        context 'no formula matched' do
          let!(:question_second) do
            question = questions.second
            question.narrator = {
              blocks: [{
                type: 'ReflectionFormula',
                action: 'NO_ACTION',
                payload: 'test',
                animation: 'rest',
                endPosition: {
                  x: 600,
                  y: 600
                },
                reflections: [
                  {
                    text: [
                      'Wrong case'
                    ],
                    match: '>2',
                    sha256: [],
                    audio_urls: []
                  }
                ]
              }],
              settings: default_narrator_settings
            }
            question.save!
          end

          before do
            get v1_user_session_questions_url(user_session.id), headers: user.create_new_auth_token
          end

          it 'returns nil target value' do
            expect(json_response['data']['attributes']['narrator']['blocks'].first['target_value']).to eq(nil)
          end
        end

        context 'formula matched' do
          let!(:question_second) do
            question = questions.second
            question.narrator = {
              blocks: [{
                type: 'ReflectionFormula',
                action: 'NO_ACTION',
                payload: 'test',
                animation: 'rest',
                endPosition: {
                  x: 600,
                  y: 600
                },
                reflections: [
                  {
                    text: [
                      'Matched case'
                    ],
                    match: '<2',
                    sha256: [],
                    audio_urls: []
                  },
                  {
                    text: [
                      'Not Matched case'
                    ],
                    match: '>2',
                    sha256: [],
                    audio_urls: []
                  }
                ]
              }],
              settings: default_narrator_settings
            }
            question.save!
          end

          before do
            get v1_user_session_questions_url(user_session.id), headers: user.create_new_auth_token
          end

          it 'returns correct target value text' do
            expect(json_response['data']['attributes']['narrator']['blocks'].first['target_value']['text'].first).to eq('Matched case')
          end
        end
      end
    end

    context 'when integration with HFHS is on' do
      let!(:next_question) { create(:question_henry_ford_initial_screen, question_group: question_group) }
      let!(:user_session_with_hfhs) do
        create(:user_session, user_id: participant.id, session_id: session.id, name_audio_id: audio_id, user_intervention: user_int)
      end

      before do
        get v1_user_session_questions_url(user_session_with_hfhs.id), headers: user.create_new_auth_token
      end

      it 'returns only data' do
        expect(json_response.keys).to match_array(%w[data answer])
      end

      it 'return correct question' do
        expect(json_response['data']['id']).to eql(next_question.id)
      end

      context 'when user has assigned patient information' do
        let(:participant) { create(:user, :confirmed, :participant, :with_hfhs_patient_detail) }

        it 'returns data and patient_details' do
          expect(json_response.keys).to match_array(%w[data answer hfhs_patient_detail])
        end
      end
    end
  end

  context 'UserSession::CatMh' do
    let(:researcher) { create(:user, :confirmed, :researcher) }
    let!(:intervention) { create(:intervention, user_id: researcher.id, status: status) }
    let(:session) { create(:cat_mh_session, :with_cat_mh_info, intervention: intervention) }
    let(:user_int) { create(:user_intervention, intervention: intervention, user: user) }
    let!(:user_session) { UserSession.create(session: session, user: participant, type: 'UserSession::CatMh', user_intervention: user_int) }
    let(:participant) { create(:user, :confirmed, :participant) }
    let(:user) { participant }
    let(:status) { 'draft' }

    before do
      get v1_user_session_questions_url(user_session.id), headers: user.create_new_auth_token
    end

    it 'question have a default settings' do
      expect(json_response['data']['attributes']).to include(
        'type' => 'Question::Single',
        'settings' => {
          'image' => false,
          'title' => true,
          'video' => false,
          'required' => true,
          'subtitle' => true,
          'proceed_button' => true,
          'narrator_skippable' => false
        }
      )
    end

    it 'have correct title and subtitle' do
      expect(json_response['data']['attributes']['subtitle']).to eq('<h1>How much of the time did you feel depressed?</h1>')
      expect(json_response['data']['attributes']['title']).to eq('Answer the following questions based on how you felt over <strong>the past 30 days</strong> unless otherwise specified.') # rubocop:disable Layout/LineLength
    end

    it 'have correct narrator block' do
      expect(json_response['data']['attributes']['narrator']['blocks'].first).to include(
        'text' => [
          'How much of the time did you feel depressed?'
        ],
        'type' => 'ReadQuestion',
        'action' => 'NO_ACTION',
        'animation' => 'rest',
        'endPosition' => {
          'x' => 600,
          'y' => 100
        }
      )
      expect(json_response['data']['attributes']['narrator']['blocks'].first['sha256']).not_to be_empty
      expect(json_response['data']['attributes']['narrator']['blocks'].first['audio_urls']).not_to be_empty
    end

    it 'have correct body' do
      expect(json_response['data']['attributes']['body']).to include(
        'data' => [
          {
            'payload' => 'None of the time',
            'value' => 1
          },
          {
            'payload' => 'A little of the time',
            'value' => 2
          },
          {
            'payload' => 'Some of the time',
            'value' => 3
          },
          {
            'payload' => 'Most of the time',
            'value' => 4
          },
          {
            'payload' => 'All of the time',
            'value' => 5
          }
        ],
        'variable' => {
          'name' => 'variable'
        }
      )
    end

    it 'return information that isn\'t first question' do
      expect(json_response['data']['attributes']['first_question']).to be(false)
    end
  end
end
