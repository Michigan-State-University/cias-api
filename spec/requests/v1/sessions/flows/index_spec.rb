# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/session/:session_id/flows?answer_id=:answer_id', type: :request do
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user_id: researcher.id, status: status) }
  let!(:session) { create(:session, intervention_id: intervention.id) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_single, question_group: question_group) }
  let(:user_session) { create(:user_session, user_id: participant.id, session_id: session.id) }
  let(:answer) { create(:answer_single, question_id: question.id, user_session_id: user_session.id) }
  let(:status) { 'draft' }

  before do
    get v1_session_flows_path(session.id), params: params, headers: user.create_new_auth_token
  end

  context 'branching logic' do
    let(:user) { participant }
    let(:params) { { answer_id: answer.id } }

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
                                 'target' => { 'id' => questions[2].id, 'type' => 'Question' }
                               }
                             ] }
        question.save
        question
      end

      it 'returns branched question id' do
        expect(json_response['data']['id']).to eq questions[2].id
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
                                 'target' => { 'id' => questions[3].id, 'type' => 'Question' }
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
                                   'target' => { 'id' => questions[3].id, 'type' => 'Question' }
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
                                   'target' => { 'id' => questions[3].id, 'type' => 'Question' }
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
                                   'target' => { 'id' => questions[3].id, 'type' => 'Question' }
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
                                   'target' => { 'id' => questions[3].id, 'type' => 'Question' }
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
    end

    context 'match nothing, return next' do
      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let!(:question) do
        question = questions.first
        question.formula = { 'payload' => 'test',
                             'patterns' => [
                               {
                                 'match' => '=2',
                                 'target' => { 'id' => questions[3].id, 'type' => 'Question' }
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
                                 'target' => { 'id' => question_feedback.id, 'type' => 'Question' }
                               }
                             ] }
        question.body = { 'data' => [{ 'value' => '1', 'payload' => '' }, { 'value' => '2', 'payload' => '' }], 'variable' => { 'name' => 'test' } }
        question.save
        question
      end

      it { expect(json_response['data']['id']).to eq question_feedback.id }
    end

    context 'response when branching is set to another session' do
      let!(:other_session) { create(:session, intervention_id: intervention.id, position: 2, schedule: schedule, schedule_at: schedule_at) }
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
                                 'target' => { 'id' => other_session.id, 'type' => 'Session' }
                               }
                             ] }
        question.body = { 'data' => [{ 'value' => '1', 'payload' => '' }, { 'value' => '2', 'payload' => '' }], 'variable' => { 'name' => 'test' } }
        question.save
        question
      end

      before do
        get v1_session_flows_path(session.id), params: params, headers: user.create_new_auth_token
      end

      context 'session that is branched to and has schedule after fill' do
        it { expect(json_response['data']['id']).to eq other_question.id }
      end

      context 'session that is branched to and has schedule exact date with schedule in the past' do
        let!(:schedule) { 'exact_date' }
        let(:schedule_at) { DateTime.now - 1.day }

        it { expect(json_response['data']['id']).to eq other_question.id }
      end

      context 'session that is branched to and has schedule days after with schedule in the past' do
        let!(:schedule) { 'days_after' }
        let(:schedule_at) { DateTime.now - 1.day }

        it { expect(json_response['data']['id']).to eq other_question.id }
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
                                 'target' => { 'id' => question_with_reflection_formula.id, 'type' => 'Question' }
                               }
                             ] }
        question.body = { 'data' => [{ 'value' => '1', 'payload' => '' }, { 'value' => '2', 'payload' => '' }], 'variable' => { 'name' => 'test' } }
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
  end
end
