# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/sessions/:session_id/questions/move', type: :request do
  let(:request) { patch v1_session_move_question_path(session_id: session.id), params: params, headers: headers }

  let!(:session) { create(:session, intervention: create(:intervention, user: user)) }
  let!(:question_group_1) { create(:question_group, title: 'Question Group 1 Title', session: session, position: 1) }
  let!(:question_group_2) { create(:question_group, title: 'Question Group 2 Title', session: session, position: 2) }
  let!(:question_1)       { create(:question_free_response, question_group: question_group_1, position: 0) }
  let!(:question_2)       { create(:question_free_response, question_group: question_group_1, position: 1) }
  let!(:question_3)       { create(:question_free_response, question_group: question_group_1, position: 2) }
  let!(:question_4)       { create(:question_free_response, question_group: question_group_2, position: 0) }
  let!(:question_5)       { create(:question_free_response, question_group: question_group_2, position: 1) }
  let!(:question_6)       { create(:question_free_response, question_group: question_group_2, position: 2) }
  let!(:question_7)       { create(:question_free_response, question_group: question_group_2, position: 3) }

  let(:params) do
    {
      question: {
        position: [
          {
            id: question_1.id,
            position: 11,
            question_group_id: question_group_2.id
          },
          {
            id: question_2.id,
            position: 22,
            question_group_id: question_group_2.id
          },
          {
            id: question_3.id,
            position: 33,
            question_group_id: question_group_2.id
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
      it 'returns serialized cloned question_group' do
        request
        positions = json_response['question_groups'][-2]['questions'].map { |position| position['position'] }

        expect(response).to have_http_status(:ok)
        expect(positions).to match_array([0, 1, 2, 3, 11, 22, 33])
        expect(response).to have_http_status(:ok)
        expect(json_response['question_groups'].size).to eq 3
        expect(question_1.reload.position).to eq 11
        expect(question_2.reload.position).to eq 22
        expect(question_3.reload.position).to eq 33
      end
    end
  end
end
