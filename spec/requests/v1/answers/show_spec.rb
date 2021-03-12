# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/user_sessions/:user_session_id/answers/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:session) { create(:session) }
  let(:user_session) { create(:user_session, user: user, session: session) }
  let(:question) { create(:question_free_response) }
  let(:answer) { create(:answer_free_response, user_session: user_session, question: question) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { get v1_user_session_answer_path(user_session_id: user_session.id, id: answer.id) }

      it { expect(response).to have_http_status(:unauthorized) }
    end

    context 'is valid' do
      before { get v1_user_session_answer_path(user_session_id: user_session.id, id: answer.id), headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when response' do
    context 'is JSON' do
      before do
        get v1_user_session_answer_path(user_session_id: user_session.id, id: answer.id), headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before do
        get v1_user_session_answer_path(user_session_id: user_session.id, id: answer.id), headers: headers
      end

      it 'to hash success' do
        expect(json_response.class).to be(Hash)
      end

      it 'key answer' do
        expect(json_response['data']['type']).to eq('answer')
      end
    end
  end
end
