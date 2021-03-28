# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/questions/:question_id/images', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:question) { create(:question_information) }
  let(:headers) do
    user.create_new_auth_token.
      merge({ 'Content-Type' => 'multipart/form-data; boundary=something' })
  end
  let(:params) do
    {
      image: {
        file: Rack::Test::UploadedFile.new('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)
      }
    }
  end

  let(:request) { post v1_question_images_path(question.id), params: params, headers: headers }

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

      it { expect(response).to have_http_status(:created) }
    end
  end
end
