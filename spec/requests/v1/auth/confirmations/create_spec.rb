# frozen_string_literal: true

require 'rails_helper'

describe 'POST /v1/auth/confirmation', type: :request do
  let!(:user) { create(:user, :researcher) }

  let(:email) { user.email }
  let(:redirect_url) { "#{ENV.fetch('WEB_URL', nil)}/login" }
  let(:params) { { email: email, redirect_url: redirect_url } }
  let(:send_request) { post '/v1/auth/confirmation', params: params }

  context 'when user with given email exists' do
    it 'returns created status with empty body' do
      send_request
      expect(response).to have_http_status(:created)
      expect(response.body).to be_empty
    end

    it 'enqueues confirmation instructions email' do
      expect { send_request }.to have_enqueued_mail(Devise::Mailer, :confirmation_instructions)
    end
  end

  context 'when user with given email does not exist' do
    let(:email) { 'not-existing-user@example.com' }

    it 'returns created status with empty body' do
      send_request
      expect(response).to have_http_status(:created)
      expect(response.body).to be_empty
    end

    it 'does not enqueue any email' do
      expect { send_request }.not_to have_enqueued_mail
    end
  end

  context 'when email is missing' do
    let(:params) { { redirect_url: redirect_url } }

    it 'returns unauthorized status with message' do
      send_request
      expect(response).to have_http_status(:unauthorized)
      expect(json_response['message']).to eq I18n.t('devise_token_auth.confirmations.missing_email')
    end
  end
end
