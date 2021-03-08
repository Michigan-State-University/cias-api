# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PUT /v1/users/send_sms_token', type: :request do
  let(:user) { create(:user, :confirmed, :participant) }
  let(:headers) { user.create_new_auth_token }
  let(:message) { create(:message, :with_code, phone: user.phone) }

  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }

  let(:phone_number) { '123456789' }
  let(:prefix) { '48' }
  let(:iso) { 'PL' }
  let(:params) do
    {
      phone_number: phone_number,
      prefix: prefix,
      iso: iso
    }
  end

  context 'when auth' do
    context 'is invalid' do
      context  'when session_id is present' do
        let(:params) do
          {
              phone_number: phone_number,
              prefix: prefix,
              iso: iso,
              session_id: session.id
          }
        end

        before { put v1_send_sms_token_path, params: params }

        it 'response contains generated uid token' do
          expect(response.headers.to_h).to include(
                                               'Uid' => include('@preview.session')
                                           )
        end
      end

      context 'when session_id is not present' do
        before { put v1_send_sms_token_path, params: params }

        it 'response contains generated uid token' do
          expect(response.headers.to_h).to include(
                                               'Uid' => include('@guest.true')
                                           )
        end
      end
    end

    context 'is valid' do
      before { put v1_send_sms_token_path, headers: headers, params: params }

      it 'response contains proper uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when phone non exist and' do
    context 'user is not logged in' do
      let(:message) { create(:message, :with_code) }
      let(:service) { Communication::Sms.new(message.id) }
      let(:user) { User.find_by(uid: response.headers.to_h['Uid']) }

      before do
        allow(service).to receive(:send_message).and_return(:double)
        allow(Communication::Sms).to receive(:new).and_return(service)
        put v1_send_sms_token_path, params: params
      end

      it 'response has status accepted' do
        expect(response.status).to eq 202
      end

      it 'creates phone object for user' do
        expect(user.phone.attributes).to include(
          'number' => phone_number,
          'prefix' => prefix,
          'iso' => iso,
          'user_id' => user.id
        )
      end
    end

    context 'user is logged in' do
      let(:message) { create(:message, :with_code) }
      let(:service) { Communication::Sms.new(message.id) }

      before do
        allow(service).to receive(:send_message).and_return(:double)
        allow(Communication::Sms).to receive(:new).and_return(service)
        put v1_send_sms_token_path, headers: headers, params: params
      end

      it 'response has status accepted' do
        expect(response.status).to eq 202
      end

      it 'creates phone object for user' do
        expect(user.phone.attributes).to include(
          'number' => phone_number,
          'prefix' => prefix,
          'iso' => iso,
          'user_id' => user.id
        )
      end
    end

    context 'user is logged in but phone number is not uniq' do
      let!(:other_user) { create(:user, :confirmed, :participant) }
      let!(:other_phone) { create(:phone, number: phone_number, prefix: prefix, iso: iso, user: other_user) }

      before do
        put v1_send_sms_token_path, headers: headers, params: params
      end

      it 'response has status accepted' do
        expect(response.status).to eq 417
      end
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
