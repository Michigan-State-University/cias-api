# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/sessions/:session_id/question_groups/:id', type: :request do
  let(:request) { patch v1_session_question_group_path(session_id: session.id, id: question_group_default.id), params: params, headers: headers }
  let(:params) do
    {
      question_group: {
        title: 'New Title'
      }
    }
  end

  let!(:session) { create(:session, problem: create(:problem, :published)) }
  let!(:question_group_default) { create(:question_group_default, title: 'Old Title', session: session) }

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

    context 'when new title is provided in params' do
      it 'returns serialized question_group' do
        request

        expect(response).to have_http_status(:ok)
        expect(json_response['title']).to eq 'New Title'
      end
    end

    context 'when new session_id is provided in params' do
      let(:new_session) { create(:session) }
      let(:params) do
        {
          question_group: {
            session_id: new_session.id
          }
        }
      end

      it 'returns serialized question_group' do
        request

        expect(response).to have_http_status(:ok)
        expect(json_response['session_id']).to eq new_session.id
      end
    end
  end
end
