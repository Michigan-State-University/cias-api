# frozen_string_literal: true

RSpec.describe Interventions::RePublishJob, type: :job do
  subject { described_class.perform_now(intervention.id) }

  let(:intervention) { create(:intervention, paused_at: 2.days.ago, status: :published) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:user_session) { create(:user_session, scheduled_at: 1.day.ago, session: session) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'cancel timeout job' do
    expect_to_call_mailer(SessionMailer, :inform_to_an_email,
                          args: [session, user_session.user.email, nil],
                          params: { locale: 'en' })
    subject
  end

  it 'cancels scheduled SMSes for the intervention' do
    expect(V1::SmsPlans::ReScheduleSmsForUserSession).to receive(:call).with(user_session)
    subject
  end
end
