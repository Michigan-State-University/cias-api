# frozen_string_literal: true

RSpec.describe SmsPlans::SendSmsJob, type: :job do
  subject { described_class.perform_now('+48123123123', 'some content', user.id) }

  let(:phone) { create(:phone, user: user) }
  let(:message) { create(:message, :with_code, phone: phone) }
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
