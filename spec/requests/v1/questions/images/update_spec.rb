# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/questions/:question_id/images', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let(:question) { create(:question_single) }
  let(:params) do
    {
      image: {
        image_alt: 'Some description'
      }
    }
  end

  let(:request) { patch v1_question_images_path(question.id), params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_question_images_path(question.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when response' do
    context 'is appropriate Content-Type' do
      before { request }

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is success' do
      before { request }

      it 'return correct status' do
        expect(response).to have_http_status(:ok)
      end

      it 'return description for image' do
        expect(json_response['data']['attributes']['image_alt']).to eq('Some description')
      end
    end
  end
end
