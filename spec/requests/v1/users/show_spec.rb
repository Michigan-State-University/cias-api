# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/users/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:alter_user) { create(:user, :confirmed) }
  let(:headers) do
    user.create_new_auth_token
  end

  context 'when endpoint is available' do
    before { get v1_user_path(id: alter_user.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        get v1_intervention_path(id: alter_user.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        get v1_user_path(id: alter_user.id), headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        get v1_user_path(id: alter_user.id), headers: headers
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
        get v1_user_path(id: alter_user.id), headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before do
        get v1_user_path(id: alter_user.id), headers: headers
      end

      it 'to hash success' do
        expect(json_response.class).to be(Hash)
      end

      it 'key question' do
        expect(json_response['data']['type']).to eq('user')
      end
    end
  end
end
