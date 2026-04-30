# frozen_string_literal: true

RSpec.describe V1::SmsPlans::ReScheduleSmsForUserSession do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

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

  describe 'participant-defined timezone (CIAS-4147 regression)' do
    # Republish path equivalent of the schedule_sms_for_user_session regression test.
    # Pre-fix: every loop iteration's `at` lands at the participant's selected hour
    # interpreted as UTC (off by their UTC offset). Post-fix: every iteration lands
    # inside the participant's window in their local zone.
    let(:participant_timezone) { 'America/Bogota' } # UTC-5, no DST
    let(:current_time) { Time.zone.parse('2026-04-29 12:00:00') }
    let(:intervention) { create(:intervention, status: 'published', paused_at: 5.days.ago) }
    let(:session) { create(:session, intervention: intervention) }
    let(:participant) { create(:user, :participant, :with_phone) }
    let!(:user_session) { create(:user_session, user: participant, session: session, finished_at: 7.days.ago) }
    let!(:sms_plan) do
      create(:sms_plan_with_text,
             session: session,
             schedule: SmsPlan.schedules[:days_after_session_end],
             schedule_payload: 1,
             frequency: 'once_a_day',
             sms_send_time_type: 'preferred_by_participant',
             end_at: 2.days.from_now)
    end
    let!(:phone_answer) do
      create(:answer_phone, user_session: user_session,
                            body: { 'data' => [
                              {
                                'var' => 'phone',
                                'value' => {
                                  'iso' => 'US', 'number' => '202-555-0173', 'prefix' => '+1', 'confirmed' => true,
                                  'time_ranges' => [{ 'from' => 7, 'to' => 9, 'label' => 'early_morning' }],
                                  'timezone' => participant_timezone
                                }
                              }
                            ] })
    end

    before do
      travel_to(current_time)
      clear_enqueued_jobs
    end

    it 'schedules every iteration inside the participant\'s window in their local zone' do
      subject

      sms_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j[:job] == SmsPlans::SendSmsJob }
      expect(sms_jobs.size).to be >= 1

      sms_jobs.each do |job|
        scheduled = Time.zone.at(job[:at]).in_time_zone(participant_timezone)
        expect(scheduled.hour).to be_between(7, 8),
                                  "expected hour in [7, 9) #{participant_timezone}, got #{scheduled} (UTC=#{Time.zone.at(job[:at]).utc})"
      end
    end
  end
end
