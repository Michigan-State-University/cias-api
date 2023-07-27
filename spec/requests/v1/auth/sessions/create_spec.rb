# frozen_string_literal: true

require 'rails_helper'

describe 'POST /v1/auth/sign_in', type: :request do
  let(:current_user) { create(:user, :admin, password: 'SomePassword1!') }
  let(:params) do
    {
      email: current_user.email,
      password: 'SomePassword1!'
    }
  end

  let(:request) { post '/v1/auth/sign_in', params: params }

  context '2FA' do
    before do
      request
    end

    it { expect(response).to have_http_status(:forbidden) }

    it { expect(json_response['details']['reason']).to eq('2FA_NEEDED') }
  end

  context 'when user hasn\'t accept T&C' do
    before do
      current_user.update!(terms: false)
      request
    end

    it { expect(response).to have_http_status(:forbidden) }

    it { expect(json_response['details']['reason']).to eq('TERMS_NOT_ACCEPTED') }
  end
end
