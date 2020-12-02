# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/questions/:question_id/answers', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:intervention) { create(:intervention, user_id: researcher.id) }
  let(:session) { create(:session, intervention_id: intervention.id) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_free_response, question_group: question_group) }

  before do
    post v1_question_answers_path(question.id), params: params, headers: user.create_new_auth_token
  end

  context 'branching logic' do
    let(:user) { researcher }
    let(:params) { params_branching }
    let(:params_branching) do
      {
        answer: {
          type: 'Answer::Single',
          user_id: user.id,
          body: {
            data: [
              {
                var: 'a1',
                value: '1'
              }
            ]
          }
        }
      }
    end

    context 'to nil because last' do
      let(:question) { create(:question_single, :branching_to_question) }

      it { expect(json_response['data']).to be_nil }
    end

    context 'response with question' do
      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let(:question) do
        question = questions.first
        question.formula = { 'payload' => 'a1',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => { 'id' => questions[1].id, 'type' => 'Question' }
                               }
                             ] }
        question
      end

      it { expect(json_response['data']['id']).to eq questions[1].id }
    end

    context 'match nothing, return next' do
      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let(:question) do
        question = questions.first
        question.formula = { 'payload' => 'a1',
                             'patterns' => [
                               {
                                 'match' => '=2',
                                 'target' => { 'id' => questions[1].id, 'type' => 'Question' }
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
                payload: 'a1',
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
        question.formula = { 'payload' => 'a1',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => { 'id' => question_feedback.id, 'type' => 'Question' }
                               }
                             ] }
        question.body = { 'data' => [{ 'value' => '1', 'payload' => '' }, { 'value' => '2', 'payload' => '' }], 'variable' => { 'name' => 'a1' } }
        question.save
        question
      end

      it { expect(json_response['data']['id']).to eq question_feedback.id }
    end

    context 'response with session' do
      let(:session) { create(:session, intervention_id: intervention.id, position: 2) }

      let(:questions) { create_list(:question_single, 3, question_group: question_group) }
      let(:question) do
        question = questions.first
        question.formula = { 'payload' => 'a1',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => { 'id' => session.id, 'type' => 'Session' }
                               }
                             ] }
        question.body = { 'data' => [{ 'value' => '1', 'payload' => '' }, { 'value' => '2', 'payload' => '' }], 'variable' => { 'name' => 'a1' } }
        question.save
        question
      end

      it { expect(json_response['data']['id']).to eq session.id }
    end

    context 'response with question with calculated target_value' do
      let(:question_with_reflection_formula) do
        question_single = build(:question_single, question_group: question_group, position: 2)
        question_single.narrator = {
          blocks: [
            {
              action: 'SHOW_USER_VALUE',
              payload: 'a1',
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

      let(:question) do
        question = build(:question_single, question_group: question_group, position: 1)
        question.formula = { 'payload' => 'a1',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => { 'id' => question_with_reflection_formula.id, 'type' => 'Question' }
                               }
                             ] }
        question.body = { 'data' => [{ 'value' => '1', 'payload' => '' }, { 'value' => '2', 'payload' => '' }], 'variable' => { 'name' => 'a1' } }
        question.save
        question
      end

      it { expect(json_response['data']['id']).to eq question_with_reflection_formula.id }

      it 'response contains target_value' do
        expect(json_response['data']['attributes']['narrator']['blocks'].first).to include(
          'target_value' => { 'text' => ['Good your value is 20.'], 'match' => '=1', 'sha256' => [], 'audio_urls' => [] }
        )
      end
    end
  end
end
