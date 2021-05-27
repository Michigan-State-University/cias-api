# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/user_session/:user_session_id/question', type: :request do
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user_id: researcher.id, status: status) }
  let!(:session) { create(:session, intervention_id: intervention.id) }
  let!(:question_group) { create(:question_group, session: session) }
  let!(:question) { create(:question_single, question_group: question_group) }
  let(:audio_id) { nil }
  let!(:user_session) do
    create(:user_session, user_id: participant.id, session_id: session.id, name_audio_id: audio_id)
  end
  let!(:answer) { create(:answer_single, question_id: question.id, user_session_id: user_session.id) }
  let(:status) { 'draft' }
  let(:user) { participant }

  before do
    get v1_user_session_questions_url(user_session.id), headers: user.create_new_auth_token
  end

  context 'branching logic' do
    context 'returns finish screen if only question' do
      it { expect(json_response['data']['attributes']['type']).to eq 'Question::Finish' }
    end

    context 'response with question' do
      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let!(:question) do
        question = questions.first
        question.formula = { 'payload' => 'test',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => [
                                   { 'id' => questions[2].id, 'probability' => '50', 'type' => 'Question' },
                                   { 'id' => questions[3].id, 'probability' => '50', 'type' => 'Question' }
                                 ]
                               }
                             ] }
        question.save
        question
      end

      it 'returns branched question id' do
        expect([questions[2].id, questions[3].id]).to include(json_response['data']['id'])
      end
    end

    context 'formula is not fully set' do
      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let!(:question) do
        question = questions.first
        question.formula = { 'payload' => 'test + test2',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => [{ 'id' => questions[3].id, 'probability' => '100', 'type' => 'Question' }]
                               }
                             ] }
        question.save
        question
      end

      it 'returns next question' do
        expect(json_response['data']['id']).to eq questions[3].id
      end

      it 'does not have warning set' do
        expect(json_response['warning']).to be nil
      end
    end

    context 'intervention is published' do
      let(:status) { 'published' }

      context 'formula is not fully set and has division' do
        let(:questions) { create_list(:question_single, 4, question_group: question_group) }
        let!(:question) do
          question = questions.first
          question.formula = { 'payload' => 'test/test2',
                               'patterns' => [
                                 {
                                   'match' => '=1',
                                   'target' => [{ 'id' => questions[3].id, 'probability' => '100',
                                                  'type' => 'Question' }]
                                 }
                               ] }
          question.save
          question
        end

        it 'returns next question' do
          expect(json_response['data']['id']).to eq questions[1].id
        end

        it 'returns correct warning' do
          expect(json_response['warning']).to eq nil
        end
      end

      context 'formula is not correctly set' do
        let(:questions) { create_list(:question_single, 4, question_group: question_group) }
        let!(:question) do
          question = questions.first
          question.formula = { 'payload' => 'test test2',
                               'patterns' => [
                                 {
                                   'match' => '=1',
                                   'target' => [{ 'id' => questions[3].id, 'probability' => '100',
                                                  'type' => 'Question' }]
                                 }
                               ] }
          question.save
          question
        end

        it 'returns next question id' do
          expect(json_response['data']['id']).to eq questions[1].id
        end

        it 'returns correct warning' do
          expect(json_response['warning']).to eq nil
        end
      end

      context 'formula has invalid target' do
        let(:questions) { create_list(:question_single, 4, question_group: question_group) }
        let!(:question) do
          question = questions.first
          question.formula = { 'payload' => 'test',
                               'patterns' => [
                                 {
                                   'match' => '=1',
                                   'target' => [{ 'id' => 'INVALID ID', 'probability' => '100', 'type' => 'Question' }]
                                 }
                               ] }
          question.save
          question
        end

        it 'returns next question' do
          expect(json_response['data']['id']).to eq questions[1].id
        end

        it 'returns correct warning' do
          expect(json_response['warning']).to eq nil
        end
      end
    end

    context 'intervention is draft' do
      context 'formula is not fully set and has division' do
        let(:questions) { create_list(:question_single, 4, question_group: question_group) }
        let!(:question) do
          question = questions.first
          question.formula = { 'payload' => 'test/test2',
                               'patterns' => [
                                 {
                                   'match' => '=1',
                                   'target' => [{ 'id' => questions[3].id, 'probability' => '100',
                                                  'type' => 'Question' }]
                                 }
                               ] }
          question.save
          question
        end

        it 'returns next question' do
          expect(json_response['data']['id']).to eq questions[1].id
        end

        it 'returns correct warning' do
          expect(json_response['warning']).to eq 'ZeroDivisionError'
        end
      end

      context 'formula is not correctly set' do
        let(:questions) { create_list(:question_single, 4, question_group: question_group) }
        let!(:question) do
          question = questions.first
          question.formula = { 'payload' => 'test test2',
                               'patterns' => [
                                 {
                                   'match' => '=1',
                                   'target' => [{ 'id' => questions[3].id, 'probability' => '100',
                                                  'type' => 'Question' }]
                                 }
                               ] }
          question.save
          question
        end

        it 'returns next question id' do
          expect(json_response['data']['id']).to eq questions[1].id
        end

        it 'returns correct warning' do
          expect(json_response['warning']).to eq 'OtherFormulaError'
        end
      end

      context 'formula has invalid target' do
        let(:questions) { create_list(:question_single, 4, question_group: question_group) }
        let!(:question) do
          question = questions.first
          question.formula = { 'payload' => 'test',
                               'patterns' => [
                                 {
                                   'match' => '=1',
                                   'target' => [{ 'id' => 'INVALID ID', 'probability' => '100', 'type' => 'Question' }]
                                 }
                               ] }
          question.save
          question
        end

        it 'returns next question' do
          expect(json_response['data']['id']).to eq questions[1].id
        end

        it 'returns correct warning' do
          expect(json_response['warning']).to eq 'NoBranchingTarget'
        end
      end
    end

    context 'match nothing, return next' do
      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let!(:question) do
        question = questions.first
        question.formula = { 'payload' => 'test',
                             'patterns' => [
                               {
                                 'match' => '=2',
                                 'target' => [{ 'id' => questions[3].id, 'probability' => '100', 'type' => 'Question' }]
                               }
                             ] }
        question
      end

      it { expect(json_response['data']['id']).to eq questions[1].id }
    end

    context 'response with feedback' do
      let(:question_feedback) do
        question_feedback = build(:question_feedback, question_group: question_group, position: 2)
        question_feedback.body = {
          data: [
            {
              payload: {
                start_value: '',
                end_value: '',
                target_value: ''
              },
              spectrum: {
                payload: 'test',
                patterns: [
                  {
                    match: '=1',
                    target: '111'
                  }
                ]
              }
            }
          ]
        }
        question_feedback.save
        question_feedback
      end

      let(:question) do
        question = build(:question_single, question_group: question_group, position: 1)
        question.formula = { 'payload' => 'test',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => [{ 'id' => question_feedback.id, 'probability' => '100',
                                                'type' => 'Question' }]
                               }
                             ] }
        question.body = { 'data' => [{ 'value' => '1', 'payload' => '' }, { 'value' => '2', 'payload' => '' }],
                          'variable' => { 'name' => 'test' } }
        question.save
        question
      end

      it { expect(json_response['data']['id']).to eq question_feedback.id }
    end

    context 'response when branching is set to another session' do
      let!(:other_session) do
        create(:session, intervention_id: intervention.id, position: 2, schedule: schedule, schedule_at: schedule_at)
      end
      let!(:other_question_group) { create(:question_group, session_id: other_session.id) }
      let!(:other_question) { create(:question_single, question_group_id: other_question_group.id) }

      let(:schedule) { :after_fill }
      let(:schedule_at) { DateTime.now + 1.day }

      let!(:questions) { create_list(:question_single, 3, question_group: question_group) }
      let!(:question) do
        question = questions.first
        question.formula = { 'payload' => 'test',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => [{ 'id' => other_session.id, 'probability' => '100', 'type' => 'Session' }]
                               }
                             ] }
        question.body = { 'data' => [{ 'value' => '1', 'payload' => '' }, { 'value' => '2', 'payload' => '' }],
                          'variable' => { 'name' => 'test' } }
        question.save
        question
      end

      before do
        get v1_user_session_questions_path(user_session.id), headers: user.create_new_auth_token
      end

      context 'session that is branched to and has schedule after fill' do
        it { expect(json_response['next_user_session_id']).not_to eq user_session.id }
      end

      context 'session that is branched to and has schedule exact date with schedule in the past' do
        let!(:schedule) { 'exact_date' }
        let(:schedule_at) { DateTime.now - 1.day }

        it { expect(json_response['next_user_session_id']).not_to eq user_session.id }
      end

      context 'session that is branched to and has schedule days after with schedule in the past' do
        let!(:schedule) { 'days_after' }
        let(:schedule_at) { DateTime.now - 1.day }

        it { expect(json_response['next_user_session_id']).not_to eq user_session.id }
      end

      %i[days_after_fill days_after exact_date].each do |schedule|
        context "session that is branched and has schedule #{schedule}" do
          let!(:schedule) { schedule }

          it 'returns question finish' do
            expect(json_response['data']['id']).to eq session.reload.finish_screen.id
          end
        end
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
          settings: {
            voice: true,
            animation: true
          }
        }
        question_single.save
        question_single
      end

      let!(:question) do
        question = build(:question_single, question_group: question_group, position: 1)
        question.formula = { 'payload' => 'test',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => [{ 'id' => question_with_reflection_formula.id, 'probability' => '100',
                                                'type' => 'Question' }]
                               }
                             ] }
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

      context 'for speech block' do
        let!(:question_with_speech_block) do
          create(:question_single, question_group: question_group, position: 2,
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
                                     settings: {
                                       voice: true,
                                       animation: true
                                     }
                                   })
        end
        let!(:question) { create(:question_single, question_group: question_group, position: 1) }

        before do
          allow_any_instance_of(Audio).to receive(:url).and_return('phonetic_audio.mp3')
          get v1_user_session_questions_path(user_session.id), headers: user.create_new_auth_token
        end

        it 'swaps url correctly' do
          expect(json_response['data']['attributes']['narrator']['blocks'].first['audio_urls'].first).to eq('phonetic_audio.mp3')
        end
      end

      context 'for ReflectionFormula block' do
        let!(:question_with_reflection_formula) do
          create(:question_single, question_group: question_group, position: 2,
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
                                     settings: {
                                       voice: true,
                                       animation: true
                                     }
                                   })
        end

        let!(:question) { create(:question_single, question_group: question_group, position: 1) }

        before do
          allow_any_instance_of(Audio).to receive(:url).and_return('phonetic_audio.mp3')
          get v1_user_session_questions_path(user_session.id), headers: user.create_new_auth_token
        end

        it 'swaps url correctly' do
          expect(json_response['data']['attributes']['narrator']['blocks'].first['reflections'].first['audio_urls'].second)
            .to eq('phonetic_audio.mp3')
        end
      end

      context 'for reflection block' do
        let!(:question_with_reflection_formula) do
          create(:question_single, question_group: question_group, position: 2,
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
                                     settings: {
                                       voice: true,
                                       animation: true
                                     }
                                   })
        end

        let!(:question) { create(:question_single, question_group: question_group, position: 1) }

        before do
          allow_any_instance_of(Audio).to receive(:url).and_return('phonetic_audio.mp3')
          get v1_user_session_questions_path(user_session.id), headers: user.create_new_auth_token
        end

        it 'swaps url correctly' do
          expect(json_response['data']['attributes']['narrator']['blocks'].first['reflections'].first['audio_urls'].first).to eq('phonetic_audio.mp3')
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
            settings: {
              voice: true,
              animation: true
            }
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
            settings: {
              voice: true,
              animation: true
            }
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
            settings: {
              voice: true,
              animation: true
            }
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
            settings: {
              voice: true,
              animation: true
            }
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
end
