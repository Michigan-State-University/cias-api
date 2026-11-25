# frozen_string_literal: true

require 'rails_helper'

describe 'GET /v1/auth/confirmation', type: :request do
  let!(:user) { create(:user, :researcher) }

  let(:web_url) { 'https://web.example.test' }
  let(:web_app_root) { web_url }
  let(:confirmation_token) { user.confirmation_token }
  let(:redirect_url) { "#{web_url}/login" }
  let(:params) { { confirmation_token: confirmation_token, redirect_url: redirect_url } }
  let(:send_request) { get '/v1/auth/confirmation', params: params }

  before { stub_const('ENV', ENV.to_hash.merge('WEB_URL' => web_url)) }

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

    { 'missing' => {}, 'empty' => { redirect_url: '' } }.each do |description, redirect_param|
      context "when redirect_url is #{description}" do
        let(:params) { { confirmation_token: confirmation_token, **redirect_param } }

        it 'confirms the user and redirects to the web app login page' do
          expect { send_request }.to change { user.reload.confirmed? }.from(false).to(true)
          expect(response).to redirect_to("#{web_url}/login?account_confirmation_success=true")
        end
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

    context 'when redirect_url is missing' do
      let(:params) { { confirmation_token: confirmation_token } }

      it 'redirects to the web app login page with failure flag' do
        send_request
        expect(response).to redirect_to("#{web_url}/login?account_confirmation_success=false")
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

  shared_examples 'rejected redirect url' do
    let(:error_query) { { error: Base64.encode64(I18n.t('users.redirect_url.invalid_link')) }.to_query }

    it 'redirects to the web app root with an error' do
      send_request
      expect(response).to redirect_to("#{web_app_root}?#{error_query}")
    end

    it 'does not confirm the user' do
      expect { send_request }.not_to change { user.reload.confirmed? }.from(false)
    end

    it 'does not enqueue welcome email' do
      expect { send_request }.not_to have_enqueued_mail(UserMailer, :welcome_email)
    end

    context 'when confirmation token is invalid' do
      let(:confirmation_token) { 'invalid_token' }

      it 'redirects to the web app root with an error' do
        send_request
        expect(response).to redirect_to("#{web_app_root}?#{error_query}")
      end
    end
  end

  {
    'web app host as the user part' => 'https://web.example.test@other.example.test/login',
    'foreign subdomain starting with the web app host' => 'https://web.example.test.other.example.test/login',
    'another port' => 'https://web.example.test:8443/login',
    'another scheme' => 'http://web.example.test/login',
    'relative path' => '/login',
    'unparseable string' => 'not a url',
    'another host' => 'https://other.example.test/login'
  }.each do |description, url|
    context "when redirect_url has #{description}" do
      let(:redirect_url) { url }

      it_behaves_like 'rejected redirect url'
    end
  end

  context 'when WEB_URL is not set' do
    let(:web_app_root) { '' }

    before { stub_const('ENV', ENV.to_hash.except('WEB_URL')) }

    it_behaves_like 'rejected redirect url'

    context 'when redirect_url is missing' do
      let(:params) { { confirmation_token: confirmation_token } }

      it_behaves_like 'rejected redirect url'
    end
  end
end
