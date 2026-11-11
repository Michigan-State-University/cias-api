# frozen_string_literal: true

RSpec.describe V1::PredefinedParticipants::DeliverSms do
  subject(:result) { described_class.call('+12015550123', 'Hello') }

  context 'when the provider accepts the message' do
    before { allow_any_instance_of(Twilio::REST::Api::V2010::AccountContext::MessageList).to receive(:create).and_return(true) }

    it 'stores the message and reports it as sent' do
      expect { result }.to change(Message, :count).by(1)
      expect(result).to be_sent
      expect(result.message.reload).to have_attributes(phone: '+12015550123', body: 'Hello', status: 'success')
    end
  end

  context 'when the provider raises' do
    before do
      allow_any_instance_of(Twilio::REST::Api::V2010::AccountContext::MessageList).to receive(:create).and_raise(Twilio::REST::TwilioError, 'x')
    end

    it 'reports the error class as the error code' do
      expect(result).not_to be_sent
      expect(result.error_code).to eq('Twilio::REST::TwilioError')
      expect(result.message.reload.status).to eq('error')
    end
  end

  context 'when the recipient opted out' do
    before do
      allow_any_instance_of(Twilio::REST::Api::V2010::AccountContext::MessageList).to receive(:create).and_return(true)
      create(:pdp_sms_opt_out, user: create(:user, :participant, :confirmed))
    end

    it 'passes the given recipient ids to the opt-out check' do
      result = described_class.call('+12015550123', 'Hello', recipient_user_ids: SmsOptOut.pluck(:user_id))
      expect(result.error_code).to eq('Communication::Sms::RecipientOptedOut')
    end
  end
end
