# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/questions/:question_id/images', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:question) { create(:question_single) }
  let(:headers) do
    user.create_new_auth_token
  end

  context 'when endpoint is available' do
    before { delete v1_images_path(question.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        delete v1_images_path(question.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        delete v1_images_path(question.id), headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        delete v1_images_path(question.id), headers: headers
      end

      it { expect(response).to have_http_status(:success) }

      it 'and response contains user token' do
        expect(response.headers['access-token']).not_to be_nil
      end
    end
  end

  context 'when response' do
    context 'is appropriate Content-Type' do
      before do
        delete v1_images_path(question.id), headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('text/html') }
    end

    context 'is success' do
      before do
        delete v1_images_path(question.id), headers: headers
      end

      it { expect(response).to have_http_status(:accepted) }
    end
  end
end
