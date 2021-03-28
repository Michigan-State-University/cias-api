# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/users/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:alter_user) { create(:user, :confirmed, :participant) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_user_path(id: alter_user.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_user_path(id: alter_user.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when response' do
    context 'is JSON' do
      before { request }

      it 'return User' do
        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        expect(json_response.class).to be(Hash)
        expect(json_response['email']).to eq(alter_user.email)
      end
    end
  end

  context 'invalid id' do
    before do
      get v1_user_path(id: 'invalid'), headers: headers
    end

    it 'returns not found' do
      expect(response).to have_http_status(:not_found)
    end
  end
end
