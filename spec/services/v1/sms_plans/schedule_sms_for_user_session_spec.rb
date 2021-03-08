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
  let(:current_time) { Time.zone.parse('2021-07-20 20:02') }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(Time).to receive(:current).and_return(current_time)
    clear_enqueued_jobs
  end

  context 'schedules testing' do
    context 'after_session_end_schedule' do
      context 'when no formula' do
        let!(:phone) { create(:phone, :confirmed, user: user, number: '202-555-0173', prefix: '+1') }

        it 'runs sms plan schedule job immediately after session end of America/New_York timezone' do
          subject

          expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(current_time).with(phone.prefix + phone.number, 'test')
        end
      end
    end

    context 'days_after_session_end_schedule' do
      let!(:sms_plan) do
        create(
          :sms_plan, session: session, no_formula_text: 'test',
                     schedule: SmsPlan.schedules[:days_after_session_end],
                     schedule_payload: 5
        )
      end

      context 'for Europe/Warsaw timezone' do
        let!(:expected_start_time) do
          Time.use_zone('Europe/Warsaw') { Time.current.next_day(5).change({ hour: 13 }).utc }
        end

        it 'run send sms job 5 days at 13 after the session ends' do
          subject

          expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(expected_start_time)
        end
      end

      context 'for America/New_York timezone' do
        let!(:phone) { create(:phone, :confirmed, user: user, number: '202-555-0173', prefix: '+1') }
        let!(:expected_start_time) do
          Time.use_zone('America/New_York') { Time.current.next_day(5).change({ hour: 13 }).utc }
        end

        it 'run send sms job 5 days at 13 after the session ends' do
          subject

          expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(expected_start_time)
        end
      end
    end
  end

  context 'frequencies testing' do
    context 'once a day' do
      let(:end_time) { Time.zone.parse('2021-07-22') }
      let!(:sms_plan) do
        create(
          :sms_plan, session: session, no_formula_text: 'test',
                     frequency: SmsPlan.frequencies[:once_a_day], end_at: end_time
        )
      end
      # 2021-07-20 13:00
      let!(:expected_start_time_1_day) do
        Time.use_zone('Europe/Warsaw') { Time.current.change({ hour: 13 }).utc }
      end
      # 2021-07-21 13:00
      let!(:expected_start_time_2_day) do
        Time.use_zone('Europe/Warsaw') { Time.current.next_day.change({ hour: 13 }).utc }
      end
      # 2021-07-22 13:00
      let!(:expected_start_time_3_day) do
        Time.use_zone('Europe/Warsaw') { Time.current.next_day(2).change({ hour: 13 }).utc }
      end

      it 'run send sms job 5 days at 13 after the session ends' do
        subject

        expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(expected_start_time_1_day)
        expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(expected_start_time_2_day)
        expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(expected_start_time_3_day)
      end
    end

    context 'once a week' do
      let(:end_time) { Time.zone.parse('2021-08-03') }
      let!(:sms_plan) do
        create(
          :sms_plan, session: session, no_formula_text: 'test',
                     frequency: SmsPlan.frequencies[:once_a_week], end_at: end_time
        )
      end
      # 2021-07-20 13:00
      let!(:expected_start_time_1_week) do
        Time.use_zone('Europe/Warsaw') { Time.current.change({ hour: 13 }).utc }
      end
      # 2021-07-27 13:00
      let!(:expected_start_time_2_week) do
        Time.use_zone('Europe/Warsaw') { Time.current.next_day(7).change({ hour: 13 }).utc }
      end
      # 2021-08-03 13:00
      let!(:expected_start_time_3_week) do
        Time.use_zone('Europe/Warsaw') { Time.current.next_day(14).change({ hour: 13 }).utc }
      end

      it 'run send sms job every day by 3 days until the end of the date' do
        subject

        expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(expected_start_time_1_week)
        expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(expected_start_time_2_week)
        expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(expected_start_time_3_week)
      end
    end

    context 'once a month' do
      let(:end_time) { Time.zone.parse('2021-09-20') }
      let!(:sms_plan) do
        create(
          :sms_plan, session: session, no_formula_text: 'test',
                     frequency: SmsPlan.frequencies[:once_a_month], end_at: end_time
        )
      end
      # 2021-07-20 13:00
      let!(:expected_start_time_1_month) do
        Time.use_zone('Europe/Warsaw') { Time.current.change({ hour: 13 }).utc }
      end
      # 2021-08-20 13:00
      let!(:expected_start_time_2_month) do
        Time.use_zone('Europe/Warsaw') { Time.current.next_day(30).change({ hour: 13 }).utc }
      end
      # 2021-09-20 13:00
      let!(:expected_start_time_3_month) do
        Time.use_zone('Europe/Warsaw') { Time.current.next_day(60).change({ hour: 13 }).utc }
      end

      it 'run send sms job every day by 3 days until the end of the date' do
        subject

        expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(expected_start_time_1_month)
        expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(expected_start_time_2_month)
        expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(expected_start_time_3_month)
      end
    end
  end
end
