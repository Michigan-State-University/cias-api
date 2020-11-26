# frozen_string_literal: true

require 'rails_helper'

describe 'DELETE /v1/sessions/:session_id/question_groups/:id/remove_questions', type: :request do
  let(:request) { delete remove_questions_v1_session_question_group_path(session_id: session.id, id: question_group.id), params: params, headers: headers }
  let(:params) do
    {
      question_group: {
        questions: questions.pluck(:id)
      }
    }
  end

  let!(:session) { create(:session, problem: create(:problem, :published)) }
  let!(:question_group) { create(:question_group, session: session) }
  let!(:questions)      { create_list(:question_free_response, 2, question_group: question_group) }

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
      expect { request }.to change { question_group.questions.count }.by(-2)

      expect(response).to have_http_status(:no_content)
    end
  end
end
