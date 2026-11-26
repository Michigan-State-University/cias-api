# frozen_string_literal: true

require 'rails_helper'

describe 'POST /v1/auth/confirmation', type: :request do
  let!(:user) { create(:user, :researcher) }

  let(:web_url) { 'https://web.example.test' }
  let(:email) { user.email }
  let(:redirect_url) { "#{web_url}/login" }
  let(:params) { { email: email, redirect_url: redirect_url } }
  let(:send_request) { post '/v1/auth/confirmation', params: params }

  before { stub_const('ENV', ENV.to_hash.merge('WEB_URL' => web_url)) }

  context 'when user with given email exists' do
    it 'returns created status with empty body' do
      send_request
      expect(response).to have_http_status(:created)
      expect(response.body).to be_empty
    end

    it 'enqueues confirmation instructions email' do
      expect { send_request }.to have_enqueued_mail(Devise::Mailer, :confirmation_instructions)
        .with(user, kind_of(String), hash_including(redirect_url: redirect_url))
    end

    context 'when redirect_url is missing' do
      let(:params) { { email: email } }

      it 'enqueues confirmation instructions email with the web app login page' do
        expect { send_request }.to have_enqueued_mail(Devise::Mailer, :confirmation_instructions)
          .with(user, kind_of(String), hash_including(redirect_url: "#{web_url}/login"))
        expect(response).to have_http_status(:created)
      end
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

  shared_examples 'rejected redirect url' do
    it 'returns unprocessable content with message' do
      send_request
      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['message']).to eq I18n.t('users.redirect_url.not_allowed')
    end

    it 'does not enqueue any email' do
      expect { send_request }.not_to have_enqueued_mail
    end

    context 'when user with given email does not exist' do
      let(:email) { 'not-existing-user@example.com' }

      it 'returns the same unprocessable content response' do
        send_request
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['message']).to eq I18n.t('users.redirect_url.not_allowed')
      end
    end
  end

  {
    'web app host as the user part' => 'https://web.example.test@other.example.test/login',
    'foreign subdomain starting with the web app host' => 'https://web.example.test.other.example.test/login',
    'another port' => 'https://web.example.test:8443/login',
    'another scheme' => 'http://web.example.test/login',
    'relative path' => '/login',
    'unparseable string' => 'not a url'
  }.each do |description, url|
    context "when redirect_url has #{description}" do
      let(:redirect_url) { url }

      it_behaves_like 'rejected redirect url'
    end
  end

  context 'when WEB_URL is not set' do
    before { stub_const('ENV', ENV.to_hash.except('WEB_URL')) }

    it_behaves_like 'rejected redirect url'

    context 'when redirect_url is missing' do
      let(:params) { { email: email } }

      it_behaves_like 'rejected redirect url'
    end
  end
end
