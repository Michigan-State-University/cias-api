# frozen_string_literal: true

require 'rails_helper'

describe 'POST /v1/sessions/:session_id/question_groups/:id/clone', type: :request do
  let(:request) { post clone_v1_session_question_group_path(session_id: session.id, id: question_group.id), headers: headers }

  let!(:session) { create(:session, intervention: create(:intervention, :published)) }
  let!(:other_session) { create(:session) }
  let!(:question_group) { create(:question_group, title: 'Question Group Title', session: session) }
  let!(:question_1) do
    create(:question_single, question_group: question_group, subtitle: 'Question Subtitle', position: 1,
                             formula: { 'payload' => 'var + 3', 'patterns' => [
                               { 'match' => '=7', 'target' => { 'id' => question_2.id, type: 'Question::Single' } }
                             ] })
  end
  let!(:question_2) do
    create(:question_single, question_group: question_group, subtitle: 'Question Subtitle 2', position: 2,
                             formula: { 'payload' => 'var + 4', 'patterns' => [
                               { 'match' => '=3', 'target' => { 'id' => other_session.id, type: 'Session' } }
                             ] })
  end

  context 'when authenticated as guest user' do
    let(:guest_user) { create(:user, :guest) }
    let(:headers)    { guest_user.create_new_auth_token }

    it 'returns forbidden status' do
      request
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when authenticated as admin user' do
    let(:admin_user) { create(:user, :admin) }
    let(:headers)    { admin_user.create_new_auth_token }

    context 'when question group does not have questions' do
      it 'returns :ok https status code' do
        request
        expect(response).to have_http_status(:ok)
      end

      it 'creates proper count of records' do
        expect { request }.to change(QuestionGroup, :count).by(1)
                                           .and change(Question, :count).by(2)
      end

      it 'returns serialized cloned question_group' do
        request

        cloned_questions = QuestionGroup.find(json_response['data']['id']).questions

        expect(json_response['data']['attributes']).to include('title' => 'Question Group Title')
        expect(json_response).to include(
          'included' => [
            include(
              'id' => cloned_questions.first.id,
              'attributes' => include(
                'subtitle' => 'Question Subtitle',
                'position' => 1,
                'body' => include(
                  'variable' => { 'name' => 'clone_' }
                ),
                'formula' => {
                  'payload' => '',
                  'patterns' => []
                }
              )
            ),
            include(
              'id' => cloned_questions.second.id,
              'attributes' => include(
                'subtitle' => 'Question Subtitle 2',
                'position' => 2,
                'body' => include(
                  'variable' => { 'name' => 'clone_' }
                ),
                'formula' => {
                  'payload' => '',
                  'patterns' => []
                }
              )
            )
          ]
        )
      end
    end
  end
end
