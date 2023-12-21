# frozen_string_literal: true

RSpec.describe V1::SmsPlans::ReScheduleSmsForUserSession do
  include ActiveJob::TestHelper
  subject { described_class.call(user_session) }

  let(:intervention) { create(:intervention, status: 'published', paused_at: 5.days.ago) }
  let(:session) { create(:session, intervention: intervention) }
  let(:participant) { create(:user, :participant, :with_phone) }
  let!(:user_session) { create(:user_session, user: participant, session: session, finished_at: 7.days.ago) }
  let!(:sms_plan) { create(:sms_plan_with_text, session: session, frequency: 'once_a_day', end_at: 2.days.ago) }

  let_it_be(:time_range) { create(:time_range) }

  before do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
  end

  it 'send 4 skipped smses' do
    expect { subject }.to have_enqueued_job(SmsPlans::SendSmsJob).at_least(4).times
  end
end
