# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/questions/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:session) { create(:session) }
  let!(:question_group) { create(:question_group, title: 'Question Group Title', session: session) }
  let!(:question) do
    create(:question_single, question_group: question_group, subtitle: 'Question Subtitle', position: 1,
                             formulas: [{
                               'payload' => 'var + 3',
                               'patterns' => [
                                 { 'match' => '=7',
                                   'target' => [{ 'id' => question2.id, 'probability' => '100',
                                                  type: 'Question::Single' }] }
                               ]
                             }],
                             body: {
                               data: [
                                 {
                                   payload: '',
                                   value: ''
                                 }
                               ],
                               variable: {
                                 name: 'variable'
                               }
                             })
  end
  let!(:question2) do
    create(:question_single, question_group: question_group, subtitle: 'Question Subtitle 2', position: 2)
  end
  let(:headers) { user.create_new_auth_token }
  let(:request) { post v1_clone_question_path(id: question.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_clone_question_path(id: question.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user clones a question' do
    context 'there is no cloned variable' do
      before { request }

      let(:question_cloned) { json_response['data']['attributes'] }

      it { expect(response).to have_http_status(:created) }

      it 'returns proper cloned object' do
        expect(question_cloned).to include(
          'subtitle' => 'Question Subtitle',
          'body' => {
            'data' => [
              {
                'payload' => '',
                'value' => '',
                'id' => anything
              }
            ],
            'variable' => {
              'name' => 'clone_variable'
            }
          },
          'formulas' => [{ 'payload' => '', 'patterns' => [] }],
          'position' => 3,
          'question_group_id' => question_group.id,
          'narrator' => question.narrator
        )
      end
    end

    context 'when there is question with same variables' do
      let!(:third_question) do
        create(:question_single, question_group: question_group, subtitle: 'Question Subtitle', position: 3,
                                 formulas: [{
                                   'payload' => 'var + 3',
                                   'patterns' => [
                                     { 'match' => '=7',
                                       'target' => [{ 'id' => question2.id, type: 'Question::Single' }] }
                                   ]
                                 }],
                                 body: {
                                   data: [
                                     {
                                       payload: '',
                                       value: ''
                                     }
                                   ],
                                   variable: {
                                     name: 'clone_variable'
                                   }
                                 })
      end
      let(:question_cloned) { json_response['data']['attributes'] }

      before { request }

      it { expect(response).to have_http_status(:created) }

      it 'returns proper cloned object' do
        expect(question_cloned).to include(
          'subtitle' => 'Question Subtitle',
          'body' => {
            'data' => [
              {
                'payload' => '',
                'value' => '',
                'id' => anything
              }
            ],
            'variable' => {
              'name' => 'clone1_variable'
            }
          },
          'formulas' => [{ 'payload' => '', 'patterns' => [] }],
          'position' => 4,
          'question_group_id' => question_group.id,
          'narrator' => question.narrator
        )
      end
    end

    context 'when assigning the cloned question position (CIAS-4161)' do
      it 'appends the clone at the end of the group instead of copying the source position' do
        request

        expect(json_response['data']['attributes']['position']).to eq(3)
        expect(question_group.questions.reload.pluck(:position)).to contain_exactly(1, 2, 3)
      end

      it 'does not produce duplicate positions within the group' do
        request

        positions = question_group.questions.reload.pluck(:position)
        expect(positions.uniq).to match_array(positions)
      end

      context 'when cloning repeatedly' do
        it 'assigns distinct, increasing positions and never collides' do
          3.times { post v1_clone_question_path(id: question.id), headers: headers }

          positions = question_group.questions.reload.order(:position).pluck(:position)
          expect(positions).to eq([1, 2, 3, 4, 5])
          expect(positions.uniq).to eq(positions)
        end
      end
    end

    context 'when user wants clone tlfb_question' do
      let!(:question) { create(:question_tlfb_question, question_group: question_group, subtitle: 'Question Subtitle', position: 1) }
      let!(:question_group) { create(:tlfb_group, session: session) }

      it 'return correct status' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user wants to clone uniq question' do
      %i[question_henry_ford_initial_screen question_name].each do |question_type|
        let(:question) { create(question_type, question_group: question_group, position: 1) }

        it 'return correct status' do
          request
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'when user wants to clone a finish question (CIAS-4161)' do
      let!(:question) { create(:question_finish, question_group: question_group) }

      it 'is forbidden so it cannot duplicate the reserved 999999 position' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
