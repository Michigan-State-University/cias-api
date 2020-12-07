# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Session', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:params) do
    { email: user.email, password: user.password }
  end

  describe 'POST /v1/auth/sign_in' do
    context 'when login params is valid' do
      before do
        post '/v1/auth/sign_in', params: params
      end

      it { expect(response).to have_http_status(:success) }

      it 'returns access-token in authentication header' do
        expect(response.headers['access-token']).to be_present
      end

      it 'returns client in authentication header' do
        expect(response.headers['client']).to be_present
      end

      it 'returns expiry in authentication header' do
        expect(response.headers['expiry']).to be_present
      end

      it 'returns uid in authentication header' do
        expect(response.headers['uid']).to be_present
      end
    end

    context 'when login params is invalid' do
      before { post '/v1/auth/sign_in' }

      it 'returns http unauthorized' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /v1/auth/sign_out' do
    it 'returns status 200' do
      headers = user.create_new_auth_token
      headers['Content-Type'] = 'application/json; charset=utf-8'
      delete '/v1/auth/sign_out', headers: headers
      expect(response).to have_http_status(:success)
    end
  end
end
