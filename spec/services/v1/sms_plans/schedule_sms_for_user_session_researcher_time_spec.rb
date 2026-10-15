# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::SmsPlans::ScheduleSmsForUserSession do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  subject { described_class.call(user_session) }

  let(:intervention) { create(:intervention, :published) }
  let(:user_intervention) { create(:user_intervention, intervention: intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:user) { create(:user, :confirmed) }
  let!(:phone) { create(:phone, :confirmed, user: user, number: '202-555-0173', prefix: '+1') }
  let(:user_session) { create(:user_session, session: session, user: user, user_intervention: user_intervention) }
  let(:current_time) { Time.zone.parse('2021-07-20 20:02') }

  before do
    ActiveJob::Base.queue_adapter = :test
    travel_to(current_time)
    clear_enqueued_jobs
  end

  describe 'researcher defined sms send time' do
    context 'when sms_send_time_type is specific_time' do
      context 'with days_after_session_end schedule' do
        let!(:sms_plan) do
          create(:sms_plan,
                 session: session,
                 no_formula_text: 'test',
                 schedule: SmsPlan.schedules[:days_after_session_end],
                 schedule_payload: 5,
                 sms_send_time_type: 'specific_time',
                 sms_send_time_details: { time: '14:30' })
        end

        it 'schedules SMS at the specific time' do
          subject

          expect(SmsPlans::SendSmsJob).to have_been_enqueued
          scheduled_at = ActiveJob::Base.queue_adapter.enqueued_jobs.last[:at]
          scheduled_datetime = Time.zone.at(scheduled_at)

          expected_time = Time.use_zone('America/New_York') do
            Time.current.next_day(5).change(hour: 14, min: 30)
          end

          expect(scheduled_datetime.to_i).to eq(expected_time.utc.to_i)
        end

        context 'when schedule_payload is 0' do
          let!(:sms_plan) do
            create(:sms_plan,
                   session: session,
                   no_formula_text: 'test',
                   schedule: SmsPlan.schedules[:days_after_session_end],
                   schedule_payload: 0,
                   sms_send_time_type: 'specific_time',
                   sms_send_time_details: { time: '16:00' })
          end

          context 'when expected time has passed' do
            let(:current_time) { Time.zone.parse('2021-07-20 20:02') }

            it 'sends SMS immediately' do
              subject

              expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(current_time)
            end
          end
        end
      end
    end

    context 'when sms_send_time_type is time_range' do
      let!(:sms_plan) do
        create(:sms_plan,
               session: session,
               no_formula_text: 'test',
               schedule: SmsPlan.schedules[:days_after_session_end],
               schedule_payload: 2,
               sms_send_time_type: 'time_range',
               sms_send_time_details: { 'from' => '9', 'to' => '11' })
      end

      it 'schedules SMS within the specified time range' do
        subject

        expect(SmsPlans::SendSmsJob).to have_been_enqueued
        scheduled_at = ActiveJob::Base.queue_adapter.enqueued_jobs.last[:at]
        scheduled_datetime = Time.zone.at(scheduled_at)

        start_range = Time.use_zone('America/New_York') do
          Time.current.next_day(2).change(hour: 9, min: 0)
        end.utc

        end_range = Time.use_zone('America/New_York') do
          Time.current.next_day(2).change(hour: 11, min: 0)
        end.utc

        expect(scheduled_datetime).to be_between(start_range, end_range)
      end
    end
  end

  describe 'participant-defined timezone (CIAS-4147 regression)' do
    # Multi-day plan + preferred_by_participant + non-Eastern timezone.
    # Pre-fix every iteration's `at` lands at the participant's selected hour
    # interpreted as UTC (off by their UTC offset). Post-fix every iteration
    # lands inside the participant's window in their local zone.
    let(:participant_timezone) { 'America/Bogota' } # UTC-5, no DST — clean validation
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
    let!(:sms_plan) do
      create(:sms_plan,
             session: session,
             no_formula_text: 'tz test',
             schedule: SmsPlan.schedules[:days_after_session_end],
             schedule_payload: 1,
             frequency: SmsPlan.frequencies[:once_a_day],
             sms_send_time_type: 'preferred_by_participant',
             end_at: current_time + 5.days)
    end

    it 'schedules every iteration inside the participant\'s window in their local zone' do
      subject

      sms_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j[:job] == SmsPlans::SendSmsJob }
      expect(sms_jobs.size).to be >= 5

      sms_jobs.each do |job|
        scheduled = Time.zone.at(job[:at]).in_time_zone(participant_timezone)
        # rand range is [from, to) so hour is 7 or 8 — never 9
        expect(scheduled.hour).to be_between(7, 8),
                                  "expected hour in [7, 9) #{participant_timezone}, got #{scheduled} (UTC=#{Time.zone.at(job[:at]).utc})"
      end
    end

    context 'with America/New_York participant (Eastern, DST-active)' do
      let(:participant_timezone) { 'America/New_York' }

      it 'schedules every iteration inside the participant\'s window in EDT/EST' do
        subject

        sms_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j[:job] == SmsPlans::SendSmsJob }
        expect(sms_jobs.size).to be >= 5

        sms_jobs.each do |job|
          scheduled = Time.zone.at(job[:at]).in_time_zone(participant_timezone)
          expect(scheduled.hour).to be_between(7, 8),
                                    "expected hour in [7, 9) #{participant_timezone}, got #{scheduled} (UTC=#{Time.zone.at(job[:at]).utc})"
        end
      end
    end
  end

  describe 'predefined participant invitation link handling' do
    subject { described_class.call(predefined_user_session) }

    let(:predefined_participant) { create(:user, :predefined_participant) }
    let!(:predefined_phone) { create(:phone, :confirmed, user: predefined_participant) }
    let(:predefined_user_session) do
      create(:user_session,
             session: session,
             user: predefined_participant,
             user_intervention: create(:user_intervention, intervention: intervention, user: predefined_participant))
    end
    let(:intervention_url) { "#{ENV.fetch('WEB_URL')}/interventions/#{intervention.id}/invite" }
    let!(:sms_plan) do
      create(:sms_plan,
             session: session,
             no_formula_text: "Check this link: #{intervention_url}",
             schedule: SmsPlan.schedules[:after_session_end])
    end

    it 'adds pid parameter to invitation link' do
      subject

      expect(SmsPlans::SendSmsJob).to have_been_enqueued

      enqueued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
      message_content = enqueued_job[:args][1]

      expect(message_content).to include("pid=#{predefined_participant.predefined_user_parameter.slug}")
    end

    context 'with session fill link' do
      let(:session_fill_url) { "#{ENV.fetch('WEB_URL')}/interventions/#{intervention.id}/sessions/#{session.id}/fill" }
      let!(:sms_plan) do
        create(:sms_plan,
               session: session,
               no_formula_text: "Fill session: #{session_fill_url}",
               schedule: SmsPlan.schedules[:after_session_end])
      end

      it 'adds pid parameter to session fill link' do
        subject

        expect(SmsPlans::SendSmsJob).to have_been_enqueued

        enqueued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
        message_content = enqueued_job[:args][1]

        expect(message_content).to include("pid=#{predefined_participant.predefined_user_parameter.slug}")
      end
    end

    context 'with link that already has query parameters' do
      let(:intervention_url) { "#{ENV.fetch('WEB_URL')}/interventions/#{intervention.id}/invite?source=email" }
      let!(:sms_plan) do
        create(:sms_plan,
               session: session,
               no_formula_text: "Check this link: #{intervention_url}",
               schedule: SmsPlan.schedules[:after_session_end])
      end

      it 'appends pid parameter to existing query string' do
        subject

        expect(SmsPlans::SendSmsJob).to have_been_enqueued

        enqueued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
        message_content = enqueued_job[:args][1]

        expect(message_content).to include('source=email')
        expect(message_content).to include("pid=#{predefined_participant.predefined_user_parameter.slug}")
      end
    end

    context 'with multiple intervention links' do
      let(:intervention_url1) { "#{ENV.fetch('WEB_URL')}/interventions/#{intervention.id}/invite" }
      let(:intervention_url2) { "#{ENV.fetch('WEB_URL')}/interventions/#{intervention.id}/sessions/#{session.id}/fill" }
      let!(:sms_plan) do
        create(:sms_plan,
               session: session,
               no_formula_text: "First: #{intervention_url1} Second: #{intervention_url2}",
               schedule: SmsPlan.schedules[:after_session_end])
      end

      it 'adds pid parameter to all intervention links' do
        subject

        expect(SmsPlans::SendSmsJob).to have_been_enqueued

        enqueued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
        message_content = enqueued_job[:args][1]

        pid_count = message_content.scan(/pid=#{predefined_participant.predefined_user_parameter.slug}/).count

        expect(pid_count).to eq(2)
      end
    end

    context 'when user is not predefined participant' do
      subject { described_class.call(regular_user_session) }

      let(:regular_user) { create(:user, :participant) }
      let!(:regular_phone) { create(:phone, :confirmed, user: regular_user) }
      let(:regular_user_session) do
        create(:user_session,
               session: session,
               user: regular_user,
               user_intervention: create(:user_intervention, intervention: intervention, user: regular_user))
      end
      let!(:sms_plan) do
        create(:sms_plan,
               session: session,
               no_formula_text: "Check this link: #{intervention_url}",
               schedule: SmsPlan.schedules[:after_session_end])
      end

      it 'does not add pid parameter to invitation link' do
        subject

        expect(SmsPlans::SendSmsJob).to have_been_enqueued

        enqueued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
        message_content = enqueued_job[:args][1]

        expect(message_content).not_to include('pid=')
        expect(message_content).to include(intervention_url)
      end
    end
  end
end
