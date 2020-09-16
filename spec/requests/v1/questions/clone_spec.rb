# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/questions/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:question) { create(:question_single) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { post v1_clone_question_path(id: question.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { post v1_clone_question_path(id: question.id), headers: headers }

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
        post v1_clone_question_path(id: question.id), headers: headers
      end

      it { expect(response).to have_http_status(:created) }
      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before do
        post v1_clone_question_path(id: question.id), headers: headers
      end

      it 'success to Hash' do
        expect(json_response.class).to be(Hash)
      end
    end

    context 'cloned' do
      before do
        post v1_clone_question_path(id: question.id), headers: headers
      end

      let(:question_was) do
        question.attributes.except('id', 'created_at', 'updated_at', 'image_url')
      end
      let(:question_cloned) do
        json_response['data']['attributes'].except('id', 'created_at', 'updated_at', 'image_url')
      end

      let(:question_was_without_body) do
        question.attributes.except('id', 'created_at', 'updated_at', 'image_url', 'body')
      end
      let(:question_cloned_without_body) do
        json_response['data']['attributes'].except('id', 'created_at', 'updated_at', 'image_url', 'body')
      end

      it 'origin and outcome same' do
        expect(question_was_without_body).to eq(question_cloned_without_body)
      end

      it 'cloned contain variable name with prefix' do
        expect(question_cloned['body']['variable']['name']).to include('clone_')
      end

      it 'formula is empty' do
        expect(question_cloned['formula']).to include({ 'payload' => '', 'patterns' => [] })
      end
    end
  end
end
