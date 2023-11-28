# frozen_string_literal: true

RSpec.describe Interventions::RePublishJob, type: :job do
  subject { described_class.perform_now(intervention.id) }

  let(:intervention) { create(:intervention, paused_at: 2.days.ago) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:user_session) { create(:user_session, scheduled_at: 1.day.ago, session: session) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'cancel timeout job' do
    # TODO: fix this test
    # allow(UserSession).to receive(:where).and_return([user_session])
    # allow(user_session).to receive(:session).and_return(session)
    # allow(user_session).to receive(:user).and_return(user_session.user)
    # allow(user_session).to receive(:health_clinic).and_return(user_session.health_clinic)
    expect(session).to receive(:send_link_to_session).with(user_session.user, user_session.health_clinic)
    subject
  end

  it 'cancels scheduled SMSes for the intervention' do
    expect(V1::SmsPlans::ReScheduleSmsForUserSession).to receive(:call).with(user_session)
    subject
  end
end
