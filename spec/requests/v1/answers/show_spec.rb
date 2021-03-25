# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/user_sessions/:user_session_id/answers/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:session) { create(:session) }
  let(:user_session) { create(:user_session, user: user, session: session) }
  let(:question) { create(:question_free_response) }
  let(:answer) { create(:answer_free_response, user_session: user_session, question: question) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_user_session_answer_path(user_session_id: user_session.id, id: answer.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_user_session_answer_path(user_session_id: user_session.id, id: answer.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when response' do
    context 'is JSON' do
      before { request }

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before { request }

      it 'to hash success' do
        expect(json_response.class).to be(Hash)
      end

      it 'key answer' do
        expect(json_response['data']['type']).to eq('answer')
      end
    end
  end
end
