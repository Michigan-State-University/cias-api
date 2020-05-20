# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/questions/:question_id/answers', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:answer) { create(:answer_text_box) }
  let(:question) { answer.question }
  let(:headers) do
    user.create_new_auth_token
  end
  let(:params) do
    {
      answer: {
        type: 'Answer::TextBox',
        body: {
          a: 1,
          b: '2',
          c: true
        }
      }
    }
  end

  let(:params_with_user) do
    {
      answer: {
        type: 'Answer::TextBox',
        user_id: user.id,
        body: {
          a: 1,
          b: '2',
          c: true
        }
      }
    }
  end

  context 'when endpoint is available' do
    before { post v1_answers_path(question.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        post v1_answers_path(question.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        post v1_answers_path(question.id), params: params, headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        post v1_answers_path(question.id), params: params, headers: headers
      end

      it { expect(response).to have_http_status(:success) }

      it 'and response contains user token' do
        expect(response.headers['access-token']).not_to be_nil
      end
    end
  end

  context 'is response header Content-Type eq JSON' do
    before do
      post v1_answers_path(question.id), params: params, headers: headers
    end

    it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
  end

  context 'when params' do
    context 'is without user' do
      before do
        post v1_answers_path(question.id), params: params, headers: headers
      end

      it { expect(response).to have_http_status(:success) }

      it 'success to Hash' do
        parsed_response = JSON.parse(response.body)
        expect(parsed_response.class).to be(Hash)
      end
    end

    context 'is with user' do
      before do
        post v1_answers_path(question.id), params: params_with_user, headers: headers
      end

      it { expect(response).to have_http_status(:success) }

      it 'success to Hash' do
        parsed_response = JSON.parse(response.body)
        expect(parsed_response.class).to be(Hash)
      end
    end
  end
end
