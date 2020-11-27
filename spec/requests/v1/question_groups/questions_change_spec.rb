# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/sessions/:session_id/question_groups/:id/questions_change', type: :request do
  let(:request) { patch questions_change_v1_session_question_group_path(session_id: session.id, id: question_group.id), params: params, headers: headers }
  let(:params) do
    {
      question_group: {
        questions: questions.pluck(:id)
      }
    }
  end

  let!(:session) { create(:session, intervention: create(:intervention, :published)) }
  let!(:question_group)  { create(:question_group, session: session, questions: []) }
  let!(:questions)       { create_list(:question_free_response, 2) }

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

    it 'returns serialized question_group' do
      expect { request }.to change { question_group.questions.count }.by(2)

      expect(response).to have_http_status(:ok)
      expect(json_response['questions'].size).to eq 2
    end
  end
end
