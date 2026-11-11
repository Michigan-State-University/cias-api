# frozen_string_literal: true

RSpec.describe SmsPlans::SendSmsJob, type: :job do
  context 'with Communication::Sms stubbed' do
    subject { described_class.perform_now('+48123123123', 'some content', nil, user.id) }

    let(:message) { create(:message, :with_code) }
    let(:service) { Communication::Sms.new(message.id) }

    before do
      allow(Communication::Sms).to receive(:new).and_return(service)
    end

    context 'enabled sms notifications' do
      let(:user) { create(:user, :confirmed, :participant) }

      it 'calls send message method' do
        expect(service).to receive(:send_message)
        subject
      end
    end

    context 'disabled sms notifications' do
      let(:user) { create(:user, :confirmed, :participant, sms_notification: false) }

      it 'dont call send message method' do
        expect(service).not_to receive(:send_message)
        subject
      end
    end
  end

  describe 'opt-out guard' do
    subject(:run_job) { described_class.perform_now(phone.full_number, 'CIAS_TDD_CANARY_BODY', nil, user.id) }

    let(:user) { create(:user, :confirmed, :participant) }
    let!(:phone) { create(:phone, :confirmed, user: user) }
    let(:twilio_messages) { instance_double(Twilio::REST::Api::V2010::AccountContext::MessageList, create: nil) }
    let(:twilio_client) { instance_double(Twilio::REST::Client, messages: twilio_messages) }

    before { allow(Twilio::REST::Client).to receive(:new).and_return(twilio_client) }

    context 'when the user has opted out' do
      before { SmsOptOut.create!(user: user, opted_out_at: Time.current) }

      it 'sends nothing to the provider' do
        run_job
        expect(twilio_messages).not_to have_received(:create)
      end
    end

    context 'when the user has not opted out' do
      it 'sends to the provider' do
        run_job
        expect(twilio_messages).to have_received(:create)
      end
    end
  end
end
