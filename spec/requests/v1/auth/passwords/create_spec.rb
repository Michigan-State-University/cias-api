# frozen_string_literal: true

require 'rails_helper'

describe 'POST /v1/auth/password', type: :request do
  let!(:user) { create(:user, :confirmed, :researcher) }

  let(:web_url) { 'https://web.example.test' }
  let(:email) { user.email }
  let(:redirect_url) { "#{web_url}/set-new-password" }
  let(:params) { { email: email, redirect_url: redirect_url } }
  let(:send_request) { post '/v1/auth/password', params: params }

  before { stub_const('ENV', ENV.to_hash.merge('WEB_URL' => web_url)) }

  context 'when user with given email exists' do
    it 'returns created status with empty body' do
      send_request
      expect(response).to have_http_status(:created)
      expect(response.body).to be_empty
    end

    it 'enqueues reset password instructions email' do
      expect { send_request }.to have_enqueued_mail(Devise::Mailer, :reset_password_instructions)
        .with(user, kind_of(String), hash_including(redirect_url: redirect_url))
    end

    it 'sets reset password token' do
      expect { send_request }.to change { user.reload.reset_password_token }.from(nil)
    end

    context 'when email has different letter case' do
      let(:email) { user.email.upcase }

      it 'finds user and enqueues email' do
        expect { send_request }.to have_enqueued_mail(Devise::Mailer, :reset_password_instructions)
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
      expect(json_response['message']).to eq I18n.t('devise_token_auth.passwords.missing_email')
    end

    it 'does not enqueue any email' do
      expect { send_request }.not_to have_enqueued_mail
    end
  end

  context 'when redirect_url is missing' do
    let(:params) { { email: email } }

    it 'returns unauthorized status with message' do
      send_request
      expect(response).to have_http_status(:unauthorized)
      expect(json_response['message']).to eq I18n.t('devise_token_auth.passwords.missing_redirect_url')
    end

    it 'does not enqueue any email' do
      expect { send_request }.not_to have_enqueued_mail
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

    it 'does not set reset password token' do
      expect { send_request }.not_to(change { user.reload.reset_password_token })
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
    'web app host as the user part' => 'https://web.example.test@other.example.test/set-new-password',
    'foreign subdomain starting with the web app host' => 'https://web.example.test.other.example.test/set-new-password',
    'another port' => 'https://web.example.test:8443/set-new-password',
    'another scheme' => 'http://web.example.test/set-new-password',
    'relative path' => '/set-new-password',
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
  end
end
