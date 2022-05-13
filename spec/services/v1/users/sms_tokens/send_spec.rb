# frozen_string_literal: true

RSpec.describe V1::Users::SmsTokens::Send do
  subject { described_class.call(user, phone_params) }

  let!(:user) { create(:user, :confirmed) }
  let!(:phone_number) { '123456789' }
  let!(:prefix) { '48' }
  let!(:iso) { 'PL' }
  let!(:phone_params) do
    {
      phone_number: phone_number,
      prefix: prefix,
      iso: iso
    }
  end
  let(:phone) { Phone.last }
  let(:message) { create(:message, :with_code, phone: prefix + phone_number) }
  let(:service) { Communication::Sms.new(message.id) }

  before do
    allow(service).to receive(:send_message).and_return(:double)
    allow(Communication::Sms).to receive(:new).and_return(service)
  end

  context 'params are empty' do
    let(:phone_params) do
      {
        phone_number: '',
        prefix: '',
        iso: ''
      }
    end

    it 'returns nil' do
      expect(subject).to be nil
    end
  end

  context 'params are proper' do
    it 'returns service' do
      expect(subject).to be service
      expect(phone.reload.confirmation_code).not_to be nil
      expect(user.phone.reload.confirmed?).to be false
    end
  end
end
