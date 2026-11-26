# frozen_string_literal: true

require 'rails_helper'

describe 'GET /v1/auth/password/edit', type: :request do
  let!(:user) { create(:user, :confirmed, :researcher) }
  let!(:reset_password_token) { user.send(:set_reset_password_token) }

  let(:web_url) { 'https://web.example.test' }
  let(:web_app_root) { web_url }
  let(:redirect_url) { "#{web_url}/set-new-password" }
  let(:params) { { reset_password_token: reset_password_token, redirect_url: redirect_url } }
  let(:send_request) { get '/v1/auth/password/edit', params: params }

  before { stub_const('ENV', ENV.to_hash.merge('WEB_URL' => web_url)) }

  context 'when redirect_url is on the web app' do
    let(:redirect_query) { Rack::Utils.parse_query(URI.parse(response.location).query) }

    it 'redirects to redirect_url with the reset and auth params' do
      send_request
      expect(response).to have_http_status(:found)
      expect(response.location).to start_with("#{redirect_url}?")
      expect(redirect_query).to include(
        'reset_password' => 'true',
        'reset_password_token' => reset_password_token,
        'uid' => user.uid
      )
      expect(user.reload.tokens.keys).to include(redirect_query['Client'])
      expect(redirect_query['Access-Token']).to be_present
    end

    it 'creates a login token' do
      expect { send_request }.to change { user.reload.tokens.to_h.size }.by(1)
    end

    it 'allows one password change without the current password' do
      expect { send_request }.to change { user.reload.allow_password_change }.from(false).to(true)
    end
  end

  context 'when reset password token is invalid' do
    let(:reset_password_token) { 'invalid-token' }

    it 'returns not found status' do
      send_request
      expect(response).to have_http_status(:not_found)
    end
  end

  shared_examples 'rejected redirect url' do
    let(:error_query) { { error: Base64.encode64(I18n.t('users.redirect_url.invalid_link')) }.to_query }

    it 'redirects to the web app root with an error' do
      send_request
      expect(response).to redirect_to("#{web_app_root}?#{error_query}")
    end

    it 'does not create a login token' do
      expect { send_request }.not_to(change { user.reload.tokens })
    end

    it 'does not allow a password change' do
      expect { send_request }.not_to(change { user.reload.allow_password_change }.from(false))
    end
  end

  {
    'web app host as the user part' => 'https://web.example.test@other.example.test/set-new-password',
    'foreign subdomain starting with the web app host' => 'https://web.example.test.other.example.test/set-new-password',
    'another port' => 'https://web.example.test:8443/set-new-password',
    'another scheme' => 'http://web.example.test/set-new-password',
    'another scheme on the web app port' => 'http://web.example.test:443/set-new-password',
    'relative path' => '/set-new-password',
    'unparseable string' => 'not a url'
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
  end
end
