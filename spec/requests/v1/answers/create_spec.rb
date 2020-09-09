# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/questions/:question_id/answers', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:question) { create(:question_text_box) }

  before { post v1_question_answers_path(question.id), params: params, headers: user.create_new_auth_token }

  context 'branching logic' do
    let(:user) { researcher }
    let(:intervention) { create(:intervention) }
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
      let(:questions) { create_list(:question_single, 4, intervention_id: intervention.id) }
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
      let(:questions) { create_list(:question_single, 4, intervention_id: intervention.id) }
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
        question_feedback = build(:question_feedback, intervention_id: intervention.id, position: 2)
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
        question = build(:question_single, intervention_id: intervention.id, position: 1)
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

    context 'response with intervention' do
      let(:problem) { create(:problem) }
      let(:intervention_response) { create(:intervention, problem_id: problem.id, position: 2) }

      let(:questions) { create_list(:question_single, 3, intervention_id: intervention.id) }
      let(:question) do
        question = questions.first
        question.formula = { 'payload' => 'a1',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => { 'id' => intervention_response.id, 'type' => 'Intervention' }
                               }
                             ] }
        question.body = { 'data' => [{ 'value' => '1', 'payload' => '' }, { 'value' => '2', 'payload' => '' }], 'variable' => { 'name' => 'a1' } }
        question.save
        question
      end

      it { expect(json_response['data']['id']).to eq intervention_response.id }
    end
  end
end
