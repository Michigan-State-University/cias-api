# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/sessions/:session_id/question_groups/position', type: :request do
  let(:user) { create(:user, :researcher) }
  let!(:session) { create(:session, intervention: create(:intervention, user: user)) }
  let!(:question_group1) { create(:question_group, session: session, position: 3) }
  let!(:question_group2) { create(:question_group, session: session, position: 4) }
  let!(:question_group3) { create(:question_group, session: session, position: 5) }
  let(:request) do
    patch position_v1_session_question_groups_path(session_id: session.id), params: params,
                                                                            headers: user.create_new_auth_token
  end

  let(:params) do
    {
      question_group: {
        position: [
          {
            id: question_group1.id,
            position: 6
          },
          {
            id: question_group2.id,
            position: 7
          },
          {
            id: question_group3.id,
            position: 8
          }
        ]
      }
    }
  end

  context 'when authenticated as researcher user' do
    context 'when question group does not have questions' do
      it 'returns serialized cloned question_group' do
        request

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq 4
        expect(question_group1.reload.position).to eq 6
        expect(question_group2.reload.position).to eq 7
        expect(question_group3.reload.position).to eq 8
      end
    end
  end
end
