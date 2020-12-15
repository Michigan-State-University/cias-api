# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PUT /v1/users/send_sms_token', type: :request do
  let(:user) { create(:user, :confirmed, :participant) }
  let(:headers) { user.create_new_auth_token }
  let(:message) { create(:message, :with_code, phone: user.phone) }

  context 'when auth' do
    context 'is invalid' do
      before { put v1_send_sms_token_path }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { put v1_send_sms_token_path, headers: headers }

      it 'response contains proper uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
        )
      end
    end
  end

  context 'when phone non exist' do
    before { put v1_send_sms_token_path, headers: headers }

    it 'response has status expectation_failed' do
      expect(response.status).to eq 417
    end
  end

  context 'when phone exist and' do
    let!(:phone) { create(:phone, user_id: user.id) }
    let(:service) { Communication::Sms.new(message.id) }

    context 'sms service respond with no error' do
      before do
        allow(service).to receive(:send_message).and_return(:double)
        allow(Communication::Sms).to receive(:new).and_return(service)
        put v1_send_sms_token_path, headers: headers
      end

      it 'response has status accepted' do
        expect(response.status).to eq 202
      end
    end

    context 'sms service respond with error' do
      before do
        put v1_send_sms_token_path, headers: headers
      end

      it 'response has status expectation_failed' do
        expect(response.status).to eq 417
      end
    end
  end
end
