# frozen_string_literal: true

RSpec.describe V1::Sms::Replay do
  include ActiveJob::TestHelper

  subject { described_class.call(from, to, body) }

  let!(:user) { create(:user, :confirmed, :participant) }
  let(:from) { '+48555777888' }
  let(:to) { '+48555444777' }

  context 'sending STOP message' do
    let(:body) { 'STOP' }
    let!(:session) { create(:session) }

    before do
      10.times do |delay|
        SmsPlans::SendSmsJob.set(wait_until: (delay + 1).days).perform_later(from, 'example content', nil, user.id, false, session.id)
      end
    end

    it 'call the method to clear jobs' do
      expect_any_instance_of(described_class).to receive(:delete_messaged_for).with(from)
      subject
    end

    context 'stop with white spaces' do
      let(:body) { ' stop ' }

      it 'call the method to clear jobs' do
        expect_any_instance_of(described_class).to receive(:delete_messaged_for).with(from)
        subject
      end
    end

    context 'body different than stop' do
      let(:body) { ' help ' }

      it 'call the method to clear jobs' do
        expect_any_instance_of(described_class).not_to receive(:delete_messaged_for).with(from)
        subject
      end
    end
  end

  context 'sending text, which matches sms_code of session' do
    context 'when session session code has proper length' do
      let(:body) { 'SMS_CODE' }
      it 'creates new user session' do
        expect_any_instance_of(described_class).to receive(:handle_message_with_sms_code)
        subject
      end
      end

    context 'when session session code does not have proper length' do
      let(:body) { 'SMS' }
      it 'does not create new user session' do
        expect_any_instance_of(described_class).not_to receive(:handle_message_with_sms_code)
        subject
      end
    end
  end
end
