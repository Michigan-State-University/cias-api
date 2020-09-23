# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/questions/:question_id/answers/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:answer) { create(:answer_free_response) }
  let(:question) { answer.question }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { get v1_question_answer_path(question_id: question.id, id: answer.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { get v1_question_answer_path(question_id: question.id, id: answer.id), headers: headers }

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
        get v1_question_answer_path(question_id: question.id, id: answer.id), headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before do
        get v1_question_answer_path(question_id: question.id, id: answer.id), headers: headers
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
