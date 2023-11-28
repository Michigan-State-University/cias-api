# frozen_string_literal: true

RSpec.describe Interventions::PauseJob, type: :job do
  subject { described_class.perform_now(intervention.id) }

  let(:intervention) { create(:intervention) }
  let(:user_session) { create(:user_session) }

  it 'set paused_at' do
    expect do
      described_class.perform_now(intervention.id)
    end.to change { intervention.reload.paused_at }.from(nil)
  end

  it 'cancel timeout job' do
    allow(UserSession).to receive(:where).and_return([user_session])
    expect(user_session).to receive(:cancel_timeout_job)
    subject
  end

  it 'cancels scheduled SMSes for the intervention' do
    expect(V1::SmsPlans::CancelScheduledSmses).to receive(:call).with(intervention.id)

    subject
  end
end
