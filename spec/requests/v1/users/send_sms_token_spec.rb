# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PUT /v1/users/send_sms_token', type: :request do
  let(:user) { create(:user, :confirmed, :participant) }
  let(:headers) { user.create_new_auth_token }
  let(:message) { create(:message, :with_code, phone: user.phone) }

  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: researcher) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_phone, question_group: question_group) }

  let(:phone_number) { '123456789' }
  let(:prefix) { '48' }
  let(:iso) { 'PL' }
  let(:params) do
    {
      phone_number: phone_number,
      prefix: prefix,
      iso: iso,
    }
  end
  let(:request) { put v1_send_sms_token_path, headers: headers, params: params }
  let(:request_with_stubbed_service) do
    allow(service).to receive(:send_message).and_return(:double)
    allow(Communication::Sms).to receive(:new).and_return(service)
    request
  end

  context 'when auth' do
    context 'is invalid' do
      let(:request) { put v1_send_sms_token_path, params: params }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  shared_examples 'creates phone for user' do
    it 'response has status accepted' do
      expect(response.status).to eq 202
    end

    it 'creates phone object for user' do
      expect(user.reload.phone.attributes).to include(
        'number' => phone_number,
        'prefix' => prefix,
        'iso' => iso,
        'user_id' => user.id
      )
    end
  end

  context 'when phone non exist and' do
    context 'user is logged in' do
      let(:message) { create(:message, :with_code) }
      let(:service) { Communication::Sms.new(message.id) }

      context 'user is preview session user' do
        let!(:user) { create(:user, :confirmed, :preview_session, preview_session_id: session.id) }

        before do
          request_with_stubbed_service
        end

        it_behaves_like 'creates phone for user'
      end

      context 'user is guest user' do
        let!(:user) { create(:user, :confirmed, :guest) }

        before do
          request_with_stubbed_service
        end

        it_behaves_like 'creates phone for user'
      end

      context 'user is super admin' do
        let!(:user) { create(:user, :confirmed, :admin) }

        before do
          request_with_stubbed_service
        end

        it_behaves_like 'creates phone for user'
      end

      context 'user is team admin' do
        let!(:user) { create(:user, :confirmed, :team_admin) }

        before do
          request_with_stubbed_service
        end

        it_behaves_like 'creates phone for user'
      end

      context 'user is researcher' do
        let!(:user) { create(:user, :confirmed, :researcher) }

        before do
          request_with_stubbed_service
        end

        it_behaves_like 'creates phone for user'
      end

      context 'user is participant' do
        before do
          request_with_stubbed_service
        end

        it_behaves_like 'creates phone for user'
      end
    end

    context 'user is logged in but phone number is not uniq' do
      let!(:other_user) { create(:user, :confirmed, :participant) }
      let!(:other_phone) { create(:phone, :confirmed, number: phone_number, prefix: prefix, iso: iso, user: other_user) }
      let(:message) { create(:message, :with_code) }
      let(:service) { Communication::Sms.new(message.id) }

      before do
        request_with_stubbed_service
      end

      it_behaves_like 'creates phone for user'

      it 'confirmations code of both users are diffrent' do
        expect(user.phone.confirmation_code).not_to eq other_phone.confirmation_code
      end

      it 'statuses of both phones are diffrent' do
        expect(user.phone.confirmed).to be false
        expect(user.phone.confirmed).not_to be other_user.phone.confirmed
      end
    end
  end

  context 'when phone exist and' do
    let!(:phone) { create(:phone, user_id: user.id) }
    let(:service) { Communication::Sms.new(message.id) }

    context 'user doesn\'t change phone number' do
      let!(:phone_number) { phone.number }
      let(:prefix) { phone.prefix }
      let(:iso) { phone.iso }

      before do
        request_with_stubbed_service
      end

      it_behaves_like 'creates phone for user'
    end

    context 'user changes phone number' do
      let!(:phone_number) { '123123123' }
      let(:prefix) { '+48' }
      let(:iso) { 'PL' }

      before do
        request_with_stubbed_service
      end

      it_behaves_like 'creates phone for user'
    end

    context 'sms service respond with error' do
      before do
        put v1_send_sms_token_path, headers: headers, params: params
      end

      it 'response has status expectation_failed' do
        expect(response.status).to eq 417
      end
    end
  end
end
