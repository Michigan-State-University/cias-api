# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/users/verify_sms_token', type: :request do
  let(:user) { create(:user, :confirmed, :participant) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { patch v1_verify_sms_token_path }

      it { expect(response).to have_http_status(:unauthorized) }
    end

    context 'is valid' do
      before { patch v1_verify_sms_token_path, headers: headers }

      it 'response contains proper uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when phone non exist' do
    before { patch v1_verify_sms_token_path, headers: headers }

    it 'response has status expectation_failed' do
      expect(response.status).to eq 417
    end
  end

  context 'when phone exist and' do
    let(:phone) { create(:phone, :unconfirmed, user_id: user.id) }
    let(:request) { patch v1_verify_sms_token_path, headers: headers, params: params }

    context 'user is not logged in' do
      let!(:user) { create(:user, :confirmed) }

      context 'token is incorrect' do
        let(:params) { { sms_token: 'not-correct-token' } }

        before { request }

        it 'response has status expectation_failed' do
          expect(response.status).to eq 417
        end
      end

      context 'token is correct' do
        let(:params) { { sms_token: phone.confirmation_code } }

        it 'response has status ok' do
          request
          expect(response.status).to eq 200
        end

        it 'changes user phone status from unconfirmed to confirmed' do
          expect { request }.to change { phone.reload.confirmed }.from(false).to(true)
        end
      end
    end

    context 'user is logged in' do
      context 'token is incorrect' do
        let(:params) { { sms_token: 'not-correct-token' } }

        before { request }

        it 'response has status expectation_failed' do
          expect(response.status).to eq 417
        end
      end

      context 'token is correct' do
        let(:params) { { sms_token: phone.confirmation_code } }

        it 'response has status ok' do
          request
          expect(response.status).to eq 200
        end

        it 'changes user phone status from unconfirmed to confirmed' do
          expect { request }.to change { phone.reload.confirmed }.from(false).to(true)
        end
      end
    end
  end
end
