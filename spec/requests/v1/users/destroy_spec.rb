# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/users/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:alter_user) { create(:user, :confirmed) }
  let(:headers) do
    user.create_new_auth_token
  end

  context 'when endpoint is available' do
    before { delete v1_user_path(id: alter_user.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        delete v1_user_path(id: alter_user.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        delete v1_user_path(id: alter_user.id), headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        delete v1_user_path(id: alter_user.id), headers: headers
      end

      it { expect(response).to have_http_status(:success) }

      it 'and response contains user token' do
        expect(response.headers['access-token']).not_to be_nil
      end
    end
  end

  context 'when response' do
    context 'is success' do
      before do
        delete v1_user_path(id: alter_user.id), headers: headers
      end

      it { expect(response).to have_http_status(:ok) }
    end
  end
end
