# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/user_sessions/:user_session_id/answers', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:user_session) { create(:user_session) }
  let(:question) { create(:question_free_response) }
  let(:answer) { create(:answer_free_response, user_session: user_session, question: question) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_user_session_answers_path(user_session.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_user_session_answers_path(user_session.id) }

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

    context 'is JSON and parse' do
      before { request }

      it 'success to Hash' do
        expect(json_response.class).to be(Hash)
      end

      it 'key data return collection' do
        expect(json_response['data'].class).to eq(Array)
      end
    end
  end
end
