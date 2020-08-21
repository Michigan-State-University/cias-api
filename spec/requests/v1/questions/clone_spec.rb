# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/questions/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:question) { create(:question_single) }
  let(:headers) do
    user.create_new_auth_token
  end

  context 'when endpoint is available' do
    before { post v1_clone_question_path(id: question.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        post v1_clone_question_path(id: question.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        post v1_clone_question_path(id: question.id), headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        post v1_clone_question_path(id: question.id), headers: headers
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

      it 'formula name is empty' do
        expect(question_cloned['formula']['payload']).to be_empty
      end
    end
  end
end
