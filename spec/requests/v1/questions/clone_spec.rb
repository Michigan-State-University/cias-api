# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/questions/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:session) { create(:session) }
  let!(:question_group) { create(:question_group, title: 'Question Group Title', session: session) }
  let!(:question) do
    create(:question_single, question_group: question_group, subtitle: 'Question Subtitle', position: 1,
                             formula: {
                               'payload' => 'var + 3',
                               'patterns' => [
                                 { 'match' => '=7',
                                   'target' => [{ 'id' => question2.id, 'probability' => '100',
                                                  type: 'Question::Single' }] }
                               ]
                             },
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
                'value' => ''
              }
            ],
            'variable' => {
              'name' => 'clone_variable'
            }
          },
          'formula' => { 'payload' => '', 'patterns' => [] },
          'position' => 3,
          'question_group_id' => question_group.id,
          'narrator' => question.narrator
        )
      end
    end

    context 'when there is question with same variables' do
      let!(:third_question) do
        create(:question_single, question_group: question_group, subtitle: 'Question Subtitle', position: 3,
                                 formula: {
                                   'payload' => 'var + 3',
                                   'patterns' => [
                                     { 'match' => '=7',
                                       'target' => [{ 'id' => question2.id, type: 'Question::Single' }] }
                                   ]
                                 },
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
                'value' => ''
              }
            ],
            'variable' => {
              'name' => 'clone1_variable'
            }
          },
          'formula' => { 'payload' => '', 'patterns' => [] },
          'position' => 4,
          'question_group_id' => question_group.id,
          'narrator' => question.narrator
        )
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
  end
end
