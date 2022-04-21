# frozen_string_literal: true

RSpec.describe V1::Users::SmsTokens::Verify do
  subject { described_class.call(user, sms_token) }

  let(:sms_token) { '1111' }
  let!(:user) { create(:user, :confirmed) }

  context 'phone exists' do
    let!(:phone) { create(:phone, user: user, confirmation_code: sms_token) }

    context 'phone token is proper' do
      it 'confirms phone number' do
        expect { subject }.to change { phone.reload.confirmed }.and change { phone.reload.confirmed_at }
      end
    end

    context 'phone token is improper' do
      let(:sms_token) { 'invalid' }

      it 'confirms phone number' do
        expect(subject).to be phone
      end
    end
  end

  context 'phone does not exist' do
    it 'confirms phone number' do
      expect(subject).to be nil
    end
  end
end
