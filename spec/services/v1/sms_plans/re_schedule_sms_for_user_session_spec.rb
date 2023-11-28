# frozen_string_literal: true

RSpec.describe V1::SmsPlans::ReScheduleSmsForUserSession do
  subject { described_class.call(user_session) }

  let(:intervention) { create(:intervention, status: 'published', paused_at: 5.days.ago) }
  let(:session) { create(:session, intervention: intervention) }
  let(:user_session) { create(:user_session, session: session, finished_at: 7.days.ago) }


end
