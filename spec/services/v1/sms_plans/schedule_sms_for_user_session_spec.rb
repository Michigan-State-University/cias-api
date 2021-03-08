# frozen_string_literal: true

RSpec.describe V1::SmsPlans::ScheduleSmsForUserSession do
  include ActiveJob::TestHelper
  subject { described_class.call(user_session) }

  let(:intervention) { create(:intervention, :published) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:sms_plan) { create(:sms_plan, session: session, no_formula_text: 'test') }
  let(:user) { create(:user, :confirmed) }
  let!(:phone) { create(:phone, :confirmed, user: user) }
  let(:user_session) { create(:user_session, session: session, user: user) }

  before do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
  end

  context 'after_session_end_schedule' do
    context 'when no formula' do
      let!(:phone) { create(:phone, :confirmed, user: user, number: '202-555-0173', prefix: '+1') }

      it 'runs sms plan schedule job immediately after session end of America/New_York timezone' do
        subject

        expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(:no_wait).with(phone.prefix + phone.number, 'test')
      end
    end
  end
end
