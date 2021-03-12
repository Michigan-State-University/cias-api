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
                                 { 'match' => '=7', 'target' => { 'id' => question_2.id, type: 'Question::Single' } }
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
  let!(:question_2) { create(:question_single, question_group: question_group, subtitle: 'Question Subtitle 2', position: 2) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { post v1_clone_question_path(id: question.id) }

      it { expect(response).to have_http_status(:unauthorized) }
    end

    context 'is valid' do
      before { post v1_clone_question_path(id: question.id), headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when user clones a question' do
    before { post v1_clone_question_path(id: question.id), headers: headers }

    let(:question_cloned) { json_response['data']['attributes'] }

    it { expect(response).to have_http_status(:created) }

    it 'returns proper cloend object' do
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
end
