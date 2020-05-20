# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/questions/:question_id/answers', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:answer) { create(:answer_text_box) }
  let(:question) { answer.question }
  let(:headers) do
    user.create_new_auth_token
  end

  context 'when endpoint is available' do
    before { get v1_answers_path(question.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        get v1_answers_path(question.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        get v1_answers_path(question.id), params: {}, headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        get v1_answers_path(question.id), params: {}, headers: headers
      end

      it { expect(response).to have_http_status(:success) }

      it 'and response contains user token' do
        expect(response.headers['access-token']).not_to be_nil
      end
    end
  end

  context 'when response' do
    context 'is JSON' do
      before do
        get v1_answers_path(question.id), params: {}, headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before do
        get v1_answers_path(question.id), params: {}, headers: headers
      end

      let(:parsed_response) { JSON.parse(response.body) }

      it 'success to Hash' do
        expect(parsed_response.class).to be(Hash)
      end

      it 'key data return collection' do
        expect(parsed_response['data'].class).to eq(Array)
      end
    end
  end
end
