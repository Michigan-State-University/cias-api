# frozen_string_literal: true

require 'rails_helper'

describe 'GET /v1/sessions/:session_id/question_groups/:id', type: :request do
  let(:request) { get v1_session_question_group_path(session_id: session.id, id: question_group.id), headers: headers }

  let!(:session) { create(:session, intervention: create(:intervention, :published)) }
  let!(:question_group) { create(:question_group, session: session, title: 'QuestionGroup Title') }
  let!(:questions)      do
    create_list(:question_free_response, 3, title: 'Question Title', question_group: question_group)
  end

  context 'when authenticated as admin user' do
    let(:guest_user) { create(:user, :admin) }
    let(:headers)    { guest_user.create_new_auth_token }

    it 'returns serialized question_group' do
      request
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['attributes']['title']).to eq 'QuestionGroup Title'
      expect(json_response['included'][0]['attributes']['title']).to eq 'Question Title'
    end
  end

  context 'when authenticated as guest user' do
    let(:guest_user) { create(:user, :guest) }
    let(:headers)    { guest_user.create_new_auth_token }

    it 'returns not found status' do
      request

      expect(response).to have_http_status(:not_found)
    end
  end
end
