# frozen_string_literal: true

require 'rails_helper'

describe 'POST /v1/auth/password', type: :request do
  let!(:user) { create(:user, :confirmed, :researcher) }

  let(:email) { user.email }
  let(:redirect_url) { "#{ENV.fetch('WEB_URL', nil)}/reset-password" }
  let(:params) { { email: email, redirect_url: redirect_url } }
  let(:send_request) { post '/v1/auth/password', params: params }

  context 'when user with given email exists' do
    it 'returns created status' do
      send_request
      expect(response).to have_http_status(:created)
    end

    it 'returns empty body, indistinguishable from the unknown email response' do
      pending 'render_create_success (head :created) is shadowed by `prepend Auth::Default`, ' \
              'so the serialized user (email, names, phone, roles, ...) is returned to an unauthenticated caller'
      send_request
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
end
