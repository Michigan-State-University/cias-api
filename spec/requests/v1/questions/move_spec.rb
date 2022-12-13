# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/sessions/:session_id/questions/move', type: :request do
  let(:request) { patch v1_session_move_question_path(session_id: session.id), params: params, headers: headers }

  let!(:session) { create(:session, intervention: create(:intervention, user: user)) }
  let!(:question_group1) { create(:question_group, title: 'Question Group 1 Title', session: session, position: 1) }
  let!(:question_group2) { create(:question_group, title: 'Question Group 2 Title', session: session, position: 2) }
  let!(:question1)       { create(:question_free_response, question_group: question_group1, position: 0) }
  let!(:question2)       { create(:question_free_response, question_group: question_group1, position: 1) }
  let!(:question3)       { create(:question_free_response, question_group: question_group1, position: 2) }
  let!(:question4)       { create(:question_free_response, question_group: question_group2, position: 0) }
  let!(:question5)       { create(:question_free_response, question_group: question_group2, position: 1) }
  let!(:question6)       { create(:question_free_response, question_group: question_group2, position: 2) }
  let!(:question7)       { create(:question_free_response, question_group: question_group2, position: 3) }

  let(:params) do
    {
      question: {
        position: [
          {
            id: question1.id,
            position: 11,
            question_group_id: question_group2.id
          },
          {
            id: question2.id,
            position: 22,
            question_group_id: question_group2.id
          },
          {
            id: question3.id,
            position: 33,
            question_group_id: question_group2.id
          },
          {
            id: question4.id,
            position: 0,
            question_group_id: question_group2.id
          },
          {
            id: question5.id,
            position: 1,
            question_group_id: question_group2.id
          },
          {
            id: question6.id,
            position: 2,
            question_group_id: question_group2.id
          },
          {
            id: question7.id,
            position: 3,
            question_group_id: question_group2.id
          }
        ]
      }
    }
  end

  context 'when authenticated as guest user' do
    let(:user) { create(:user, :guest) }
    let(:headers) { user.create_new_auth_token }

    it 'returns forbidden status' do
      request

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when authenticated as researcher user' do
    let(:user) { create(:user, :researcher) }
    let(:headers) { user.create_new_auth_token }

    context 'when question group does not have questions' do
      before { request }

      it 'returns serialized cloned question_group' do
        expect(response).to have_http_status(:ok)
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq 3
        expect(question1.reload.position).to eq 11
        expect(question2.reload.position).to eq 22
        expect(question3.reload.position).to eq 33
      end

      it 'changes question groups question count' do
        expect(question_group2.reload.questions_count).to eq(7)
      end
    end
  end
end
