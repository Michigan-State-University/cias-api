# frozen_string_literal: true

require 'rails_helper'

describe 'GET /v1/auth/confirmation', type: :request do
  let!(:user) { create(:user, :researcher) }

  let(:confirmation_token) { user.confirmation_token }
  let(:redirect_url) { "#{ENV.fetch('WEB_URL', nil)}/login" }
  let(:params) { { confirmation_token: confirmation_token, redirect_url: redirect_url } }
  let(:send_request) { get '/v1/auth/confirmation', params: params }

  context 'when confirmation token is valid' do
    it 'confirms the user' do
      expect { send_request }.to change { user.reload.confirmed? }.from(false).to(true)
    end

    it 'redirects to redirect_url with success flag' do
      send_request
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to("#{redirect_url}?account_confirmation_success=true")
    end

    it 'enqueues welcome email' do
      expect { send_request }.to have_enqueued_mail(UserMailer, :welcome_email)
    end

    context 'when redirect_url points outside of the web app' do
      let(:redirect_url) { 'https://evil.example.com/login' }

      it 'does not allow redirecting to other host' do
        expect { send_request }.to raise_error(ActionController::Redirecting::OpenRedirectError)
      end
    end
  end

  context 'when confirmation token is invalid' do
    let(:confirmation_token) { 'invalid_token' }

    it 'redirects to redirect_url with failure flag' do
      send_request
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to("#{redirect_url}?account_confirmation_success=false")
    end

    it 'does not confirm the user' do
      expect { send_request }.not_to change { user.reload.confirmed? }.from(false)
    end

    it 'does not enqueue welcome email' do
      expect { send_request }.not_to have_enqueued_mail(UserMailer, :welcome_email)
    end

    context 'when redirect_url points outside of the web app' do
      let(:redirect_url) { 'https://evil.example.com/login' }

      it 'does not allow redirecting to other host' do
        expect { send_request }.to raise_error(ActionController::Redirecting::OpenRedirectError)
      end
    end

    context 'when redirect_url is missing' do
      let(:params) { { confirmation_token: confirmation_token } }

      it 'returns not found status' do
        send_request
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context 'when user is already confirmed' do
    let!(:user) { create(:user, :confirmed, :researcher) }

    it 'redirects to redirect_url with failure flag' do
      send_request
      expect(response).to redirect_to("#{redirect_url}?account_confirmation_success=false")
    end

    it 'does not enqueue welcome email' do
      expect { send_request }.not_to have_enqueued_mail(UserMailer, :welcome_email)
    end
  end

  context 'when confirmation token is missing' do
    let(:params) { { redirect_url: redirect_url } }

    it 'redirects to redirect_url with failure flag' do
      send_request
      expect(response).to redirect_to("#{redirect_url}?account_confirmation_success=false")
    end
  end
end
