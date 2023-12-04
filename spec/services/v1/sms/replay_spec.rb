# frozen_string_literal: true

RSpec.describe V1::Sms::Replay do
  include ActiveJob::TestHelper

  subject { described_class.call(from, to, body) }

  let!(:user) { create(:user, :confirmed, :participant) }
  let!(:session) { create(:session) }
  let(:from) { '+48555777888' }
  let(:to) { '+48555444777' }
  let(:body) { 'STOP' }

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
