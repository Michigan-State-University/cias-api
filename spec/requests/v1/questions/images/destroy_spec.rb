# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/questions/:question_id/images', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:question) { create(:question_information) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { delete v1_question_images_path(question.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { delete v1_question_images_path(question.id) }

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

      it { expect(response).to have_http_status(:ok) }
    end
  end

  context 'when the question has an image' do
    before do
      question.image.attach(FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true))
    end

    it 'removes the attachment and its blob' do
      blob_id = question.image.blob.id
      request

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['attributes']).to include('image_url' => nil, 'image_alt' => nil)
      expect(question.reload.image).not_to be_attached
      expect(ActiveStorage::Blob.exists?(blob_id)).to be false
    end
  end
end
