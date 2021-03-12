# frozen_string_literal: true

RSpec.describe SmsPlans::SendSmsJob, type: :job do
  subject { described_class.perform_now('+48123123123', 'some content') }

  let(:user) { create(:user, :confirmed, :participant) }
  let(:phone) { create(:phone, user: user) }
  let(:message) { create(:message, :with_code, phone: phone) }
  let(:service) { Communication::Sms.new(message.id) }

  before do
    allow(Communication::Sms).to receive(:new).and_return(service)
  end

  it 'calls send message method' do
    expect(service).to receive(:send_message)

    subject
  end
end
