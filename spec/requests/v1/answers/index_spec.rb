# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/questions/:question_id/answers', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:answer) { create(:answer_text_box) }
  let(:question) { answer.question }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { get v1_question_answers_path(question.id) }

      it { expect(response).to have_http_status(:ok) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { get v1_question_answers_path(question.id), headers: headers }

      it { expect(response).to have_http_status(:success) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
        )
      end
    end
  end

  context 'when response' do
    context 'is JSON' do
      before do
        get v1_question_answers_path(question.id), headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before do
        get v1_question_answers_path(question.id), headers: headers
      end

      it 'success to Hash' do
        expect(json_response.class).to be(Hash)
      end

      it 'key data return collection' do
        expect(json_response['data'].class).to eq(Array)
      end
    end
  end
end
