# frozen_string_literal: true

RSpec.describe V1::SmsPlans::ScheduleSmsForUserSession do
  include ActiveJob::TestHelper
  include Rails.application.routes.url_helpers
  subject { described_class.call(user_session) }

  let(:intervention) { create(:intervention, :published) }
  let(:user_intervention) { create(:user_intervention, intervention: intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:session2) { create(:session, intervention: intervention) }
  let!(:sms_plan) { create(:sms_plan, session: session, no_formula_text: 'test') }
  let(:user) { create(:user, :confirmed) }
  let!(:phone) { create(:phone, :confirmed, user: user) }
  let(:user_session) { create(:user_session, session: session, user: user, user_intervention: user_intervention) }
  let(:user_session2) { create(:user_session, session: session2, user: user, user_intervention: user_intervention) }
  let(:current_time) { Time.zone.parse('2021-07-20 20:02') }

  let_it_be(:time_range) { create(:time_range) }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(Time).to receive(:current).and_return(current_time)
    clear_enqueued_jobs
  end

  context 'no formula' do
    context 'schedules testing' do
      context 'after_session_end_schedule' do
        context 'when no formula' do
          let!(:phone) { create(:phone, :confirmed, user: user, number: '202-555-0173', prefix: '+1') }

          it 'send sms immediately after session end of America/New_York timezone' do
            subject

            expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(current_time).with(
              phone.prefix + phone.number, 'test', nil, user.id, false, session.id
            )
          end

          context 'when sms plan has an attached image' do
            let!(:sms_plan) { create(:sms_plan, :with_no_formula_attachment, session: session, no_formula_text: 'test') }

            it 'send sms immediately after session end of America/New_York timezone' do
              subject

              expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(current_time).with(
                phone.prefix + phone.number, 'test', url_for(sms_plan.no_formula_attachment), user.id, false, session.id
              )
            end
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
          let(:start_of_time_range) do
            Time.use_zone('Europe/Warsaw') { Time.current.next_day(5).change({ hour: 12 }).to_i }
          end
          let(:end_of_time_range) do
            Time.use_zone('Europe/Warsaw') { Time.current.next_day(5).change({ hour: 17 }).to_i }
          end

          it 'send sms for 5 days between 12 and 17 after the session ends' do
            subject
            scheduled_at = ActiveJob::Base.queue_adapter.enqueued_jobs.last[:at]

            expect(SmsPlans::SendSmsJob).to have_been_enqueued
            expect(scheduled_at).to be_between(start_of_time_range, end_of_time_range)
          end

          context 'when the user selects a different time zone than indicated by the phone number' do
            let!(:phone_answer) do
              create(:answer_phone, user_session: user_session,
                                    body: {
                                      'data' => [
                                        {
                                          'var' => 'phone',
                                          'value' => { 'iso' => 'PL', 'number' => '123123123', 'prefix' => '+48', 'confirmed' => true,
                                                       'time_ranges' => [{ 'from' => '9', 'to' => '13' }], 'time_zone' => 'Asia/Baku' }
                                        }
                                      ]
                                    })
            end

            let(:start_of_time_range) do
              Time.use_zone('Asia/Baku') { Time.current.next_day(5).change({ hour: 9 }).to_i }
            end
            let(:end_of_time_range) do
              Time.use_zone('Asia/Baku') { Time.current.next_day(5).change({ hour: 13 }).to_i }
            end

            it 'send sms for 5 days between 9 and 13 after the session ends' do
              clear_enqueued_jobs
              subject
              scheduled_at = ActiveJob::Base.queue_adapter.enqueued_jobs.last[:at]

              expect(SmsPlans::SendSmsJob).to have_been_enqueued
              expect(scheduled_at).to be_between(start_of_time_range, end_of_time_range)
            end
          end

          context 'when user defined preferable time ranges' do
            let!(:phone_answer) do
              create(:answer_phone, user_session: user_session,
                                    body: {
                                      'data' => [
                                        {
                                          'var' => 'phone',
                                          'value' => { 'iso' => 'PL', 'number' => '123123123', 'prefix' => '+48', 'confirmed' => true,
                                                       'time_ranges' => [{ 'from' => '11', 'to' => '12' }] }
                                        }
                                      ]
                                    })
            end
            let(:start_of_range) do
              Time.use_zone('Europe/Warsaw') { Time.current.next_day(5).change({ hour: 11 }).utc }
            end
            let(:end_of_range) do
              Time.use_zone('Europe/Warsaw') { Time.current.next_day(5).change({ hour: 12 }).utc }
            end

            it 'send sms for 5 days at 13 after the session ends' do
              subject
              scheduled_time = ActiveJob::Base.queue_adapter.enqueued_jobs.last[:at].to_d
              scheduled_datetime = Time.zone.at(scheduled_time)
              expect(scheduled_datetime).to be_between(start_of_range, end_of_range)
            end
          end
        end

        context 'for America/New_York timezone' do
          let!(:phone) { create(:phone, :confirmed, user: user, number: '202-555-0173', prefix: '+1') }
          let(:start_of_range) do
            Time.use_zone('America/New_York') { Time.current.next_day(5).change({ hour: 12 }).to_i }
          end
          let(:end_of_range) do
            Time.use_zone('America/New_York') { Time.current.next_day(5).change({ hour: 17 }).to_i }
          end

          it 'send sms for 5 days at 13 after the session ends' do
            subject
            scheduled_at = ActiveJob::Base.queue_adapter.enqueued_jobs.last[:at]

            expect(SmsPlans::SendSmsJob).to have_been_enqueued
            expect(scheduled_at).to be_between(start_of_range, end_of_range)
          end
        end

        context 'when the number of days is 0' do
          let!(:sms_plan) do
            create(
              :sms_plan, session: session, no_formula_text: 'test',
                         schedule: SmsPlan.schedules[:days_after_session_end],
                         schedule_payload: 0
            )
          end

          it 'send sms immediately after session end' do
            subject
            expect(SmsPlans::SendSmsJob).to have_been_enqueued.at(current_time)
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
        # 2021-07-20 12:00-17:00
        let(:start_of_first_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.change({ hour: 12 }).to_i }
        end
        let(:end_of_first_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.change({ hour: 17 }).to_i }
        end
        # 2021-07-21 12:00-17:00
        let(:start_of_second_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.next_day.change({ hour: 12 }).to_i }
        end
        let(:end_of_second_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.next_day.change({ hour: 17 }).to_i }
        end
        # 2021-07-22 12:00-17:00
        let(:start_of_third_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.next_day(2).change({ hour: 12 }).to_i }
        end
        let(:end_of_third_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.next_day(2).change({ hour: 17 }).to_i }
        end

        it 'send sms for 5 days at 13 after the session ends' do
          expect { subject }.to have_enqueued_job(SmsPlans::SendSmsJob).at_least(3).times
        end

        it 'each sms will be send in default time range' do
          subject

          scheduled_at_tab = ActiveJob::Base.queue_adapter.enqueued_jobs.pluck(:at).sort
          expect(scheduled_at_tab[0]).to be_between(start_of_first_range, end_of_first_range)
          expect(scheduled_at_tab[1]).to be_between(start_of_second_range, end_of_second_range)
          expect(scheduled_at_tab[2]).to be_between(start_of_third_range, end_of_third_range)
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
        # 2021-07-20 12:00-17:00
        let(:start_of_first_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.change({ hour: 12 }).to_i }
        end
        let(:end_of_first_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.change({ hour: 17 }).to_i }
        end
        # 2021-07-27 12:00-17:00
        let(:start_of_second_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.next_day(7).change({ hour: 12 }).to_i }
        end
        let(:end_of_second_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.next_day(7).change({ hour: 17 }).to_i }
        end
        # 2021-08-03 12:00-17:00
        let(:start_of_third_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.next_day(14).change({ hour: 12 }).to_i }
        end
        let(:end_of_third_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.next_day(14).change({ hour: 17 }).to_i }
        end

        it 'send sms every day by 3 days until the end of the date' do
          expect { subject }.to have_enqueued_job(SmsPlans::SendSmsJob).at_least(3).times
        end

        it 'each sms will be send in default time range' do
          subject

          scheduled_at_tab = ActiveJob::Base.queue_adapter.enqueued_jobs.pluck(:at).sort
          expect(scheduled_at_tab[0]).to be_between(start_of_first_range, end_of_first_range)
          expect(scheduled_at_tab[1]).to be_between(start_of_second_range, end_of_second_range)
          expect(scheduled_at_tab[2]).to be_between(start_of_third_range, end_of_third_range)
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
        # 2021-07-20 12:00 - 17:00
        let(:start_of_first_time_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.change({ hour: 12 }).to_i }
        end
        let(:end_of_first_time_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.change({ hour: 17 }).to_i }
        end
        # 2021-08-20 12:00 - 17:00
        let(:start_of_second_time_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.next_day(30).change({ hour: 12 }).to_i }
        end
        let(:end_of_second_time_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.next_day(30).change({ hour: 17 }).to_i }
        end
        # 2021-09-20 12:00 - 17:00
        let(:start_of_third_time_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.next_day(60).change({ hour: 12 }).to_i }
        end
        let(:end_of_third_time_range) do
          Time.use_zone('Europe/Warsaw') { Time.current.next_day(60).change({ hour: 17 }).to_i }
        end

        it 'send sms every day by 3 days until the end of the date' do
          expect { subject }.to have_enqueued_job(SmsPlans::SendSmsJob).at_least(3).times
        end

        it 'each sms will be send in default time range' do
          subject

          scheduled_at_tab = ActiveJob::Base.queue_adapter.enqueued_jobs.pluck(:at).sort
          expect(scheduled_at_tab[0]).to be_between(start_of_first_time_range, end_of_first_time_range)
          expect(scheduled_at_tab[1]).to be_between(start_of_second_time_range, end_of_second_time_range)
          expect(scheduled_at_tab[2]).to be_between(start_of_third_time_range, end_of_third_time_range)
        end
      end
    end
  end

  context "the cases when sms shouldn't be sent" do
    context 'when the session is not published' do
      let(:intervention) { create(:intervention) }

      it 'dont send sms' do
        subject
        expect(SmsPlans::SendSmsJob).not_to have_been_enqueued
      end
    end

    context 'when the phone is not confirmed' do
      let!(:phone) { create(:phone, user: user) }

      it 'dont send sms' do
        subject
        expect(SmsPlans::SendSmsJob).not_to have_been_enqueued
      end
    end

    context 'when the phone does not exist' do
      let!(:phone) { nil }

      it 'dont send sms' do
        subject
        expect(SmsPlans::SendSmsJob).not_to have_been_enqueued
      end
    end

    context 'when is_used_formula is false and no_formula_text is blank' do
      let!(:sms_plan) { create(:sms_plan, session: session) }

      it 'dont send sms' do
        subject
        expect(SmsPlans::SendSmsJob).not_to have_been_enqueued
      end
    end

    context 'when we have formula without any matched variants' do
      let!(:question_body) do
        {
          'data' => [
            { 'value' => '1', 'payload' => '' }
          ],
          'variable' => { 'name' => 'var1' }
        }
      end
      let!(:answer_body) do
        {
          'data' => [
            {
              'var' => 'var1',
              'value' => '1'
            }
          ]
        }
      end
      let!(:question_group) { create(:question_group_plain, session: session) }
      let!(:question) { create(:question_single, question_group: question_group, body: question_body) }
      let!(:answer) { create(:answer_single, question: question, body: answer_body, user_session: user_session) }
      let!(:sms_plan) { create(:sms_plan, session: session, is_used_formula: true, formula: 'var1 + 1') }
      let!(:variant) do
        create(:sms_plan_variant, sms_plan: sms_plan, formula_match: '=5', content: 'variant content')
      end

      it 'dont send sms' do
        subject
        expect(SmsPlans::SendSmsJob).not_to have_been_enqueued
      end
    end

    context 'when we have formula without any variants' do
      let!(:sms_plan) { create(:sms_plan, session: session, is_used_formula: true, formula: 'var1 + 1') }

      it 'dont send sms' do
        subject
        expect(SmsPlans::SendSmsJob).not_to have_been_enqueued
      end
    end

    context 'when is_used_formula is true and the formula is blank' do
      let!(:sms_plan) { create(:sms_plan, session: session, is_used_formula: true) }

      it 'dont send sms' do
        subject
        expect(SmsPlans::SendSmsJob).not_to have_been_enqueued
      end
    end

    context 'when user does not have enabled sms notifications' do
      let(:user) { create(:user, :confirmed, sms_notification: false) }

      it 'dont send sms' do
        subject
        expect(SmsPlans::SendSmsJob).not_to have_been_enqueued
      end
    end
  end

  context 'with formula' do
    let!(:question_body) do
      {
        'data' => [
          { 'value' => '1', 'payload' => '' }
        ],
        'variable' => { 'name' => 'var1' }
      }
    end
    let!(:answer_body) do
      {
        'data' => [
          {
            'var' => 'var1',
            'value' => '1'
          }
        ]
      }
    end
    let!(:question_group) { create(:question_group_plain, session: session) }
    let!(:question) { create(:question_single, question_group: question_group, body: question_body) }
    let!(:answer) { create(:answer_single, question: question, body: answer_body, user_session: user_session) }
    let!(:sms_plan) { create(:sms_plan, session: session, is_used_formula: true, formula: 'var1 + 1') }

    context 'with name variable' do
      let!(:answer_receive_report_true) do
        create(:answer_name, user_session: user_session,
                             body: { data: [
                               { 'var' => '.:name:.', 'value' => { 'name' => 'John', 'phonetic_name' => 'John' } }
                             ] })
      end
      let!(:variant1) do
        create(:sms_plan_variant, sms_plan: sms_plan, formula_match: '=2', content: 'Hello .:name:.!')
      end
      let!(:variant2) do
        create(:sms_plan_variant, sms_plan: sms_plan, formula_match: '>1', content: 'Hello .:name:.!')
      end

      context 'when two variants match to formula' do
        it 'send sms with content of first variant' do
          subject
          expect(SmsPlans::SendSmsJob).to have_been_enqueued.with(
            phone.prefix + phone.number, 'Hello John!', nil, user.id, false, session.id
          )
        end
      end
    end

    context 'with other variable' do
      let!(:answer_receive_report_true) do
        create(:answer_number, user_session: user_session2,
                               body: { data: [
                                 { 'var' => 'number', 'value' => '1234' }
                               ] })
      end
      let!(:variant1) do
        create(:sms_plan_variant, sms_plan: sms_plan, formula_match: '=2',
                                  content: "variant 1 content, value: .:var1:., prev_value: .:#{session2.variable}.number:.")
      end
      let!(:variant2) do
        create(:sms_plan_variant, sms_plan: sms_plan, formula_match: '>1',
                                  content: "variant 1 content, value: .:var1:., prev_value: .:#{session2.variable}.number:.")
      end

      context 'when two variants match to formula' do
        it 'send sms with content of first variant' do
          subject
          expect(SmsPlans::SendSmsJob).to have_been_enqueued.with(
            phone.prefix + phone.number, 'variant 1 content, value: 1, prev_value: 1234', nil, user.id, false, session.id
          )
        end
      end

      context 'with attached image to the variant' do
        let!(:variant1) do
          create(:sms_plan_variant, :with_attachment, sms_plan: sms_plan, formula_match: '=2',
                                                      content: "variant 1 content, value: .:var1:., prev_value: .:#{session2.variable}.number:.")
        end

        it 'send sms with content of first variant' do
          subject
          expect(SmsPlans::SendSmsJob).to have_been_enqueued.with(
            phone.prefix + phone.number, 'variant 1 content, value: 1, prev_value: 1234', url_for(variant1.attachment), user.id, false, session.id
          )
        end
      end
    end
  end

  context 'sms alerts' do
    let!(:user) { create(:user, :confirmed, :researcher, first_name: 'Randy', last_name: 'Rhoads', email: 'not.black.sabbath@gmail.com') }
    let!(:phone) { create(:phone, :confirmed, user: user) }
    let!(:intervention) { create(:intervention, :published) }
    let!(:session) { create(:session, intervention: intervention) }
    let!(:user_session) { create(:user_session, user: user, session: session) }
    let!(:sms_plan) { create(:alert_with_personal_data, session: session) }
    let!(:sms_phone_number) { AlertPhone.create!(sms_plan: sms_plan, phone: phone) }
    let!(:content) { "#{user.first_name} #{user.last_name}\n#{user.email}\n#{phone.prefix}#{phone.number}\n#{sms_plan.no_formula_text}" }
    let!(:number) { phone.prefix + phone.number }

    shared_examples 'correct sms job queue' do
      it do
        subject
        expect(SmsPlans::SendSmsJob).to have_been_enqueued.with(number, content, nil, user.id, true, session.id)
      end
    end

    context 'when the participant blocks sms notifications' do
      let!(:user) do
        create(:user, :confirmed, :researcher, first_name: 'Randy', last_name: 'Rhoads', email: 'not.black.sabbath@gmail.com', sms_notification: false)
      end

      it_behaves_like 'correct sms job queue'
    end

    context 'correctly applies personal data' do
      context 'when all are selected' do
        it_behaves_like 'correct sms job queue'
      end

      context 'when 3 are selected' do
        let!(:sms_plan) { create(:sms_alert, session: session, include_email: true, include_first_name: true, include_last_name: true) }
        let!(:content) { "#{user.first_name} #{user.last_name}\n#{user.email}\n#{sms_plan.no_formula_text}" }

        it_behaves_like 'correct sms job queue'
      end

      context 'when 2 are selected' do
        let!(:sms_plan) { create(:sms_alert, session: session, include_email: true, include_first_name: true) }
        let!(:content) { "#{user.first_name}\n#{user.email}\n#{sms_plan.no_formula_text}" }

        it_behaves_like 'correct sms job queue'
      end

      context 'when a single one is selected' do
        let!(:sms_plan) { create(:sms_alert, session: session, include_email: true) }
        let!(:content) { "#{user.email}\n#{sms_plan.no_formula_text}" }

        it_behaves_like 'correct sms job queue'
      end

      context 'when no data is selected' do
        let!(:sms_plan) { create(:sms_alert, session: session) }
        let!(:content) { "No personal data provided\n#{sms_plan.no_formula_text}" }

        it_behaves_like 'correct sms job queue'
      end

      context 'when data is included but missing from user' do
        let!(:user) { create(:user, :confirmed, :researcher, first_name: 'Randy', last_name: 'Rhoads', email: 'not.black.sabbath@gmail.com') }
        let!(:phone) { create(:phone, :confirmed, user: user) }
        let!(:intervention) { create(:intervention, :published) }
        let!(:session) { create(:session, intervention: intervention) }
        let!(:sms_plan) { create(:alert_with_personal_data, session: session) }
        let!(:sms_phone_number) { AlertPhone.create!(sms_plan: sms_plan, phone: phone) }

        context 'when last name is missing' do
          let!(:participant) { create(:user, :participant, :confirmed, first_name: 'Randall', last_name: nil, email: 'not.black.sabbath1@gmail.com') }
          let!(:participant_phone) { create(:phone, :confirmed, user: participant) }
          let!(:user_session) { create(:user_session, user: participant, session: session) }
          let!(:content) do
            "#{participant.first_name}\nLast name not provided\n#{participant.email}\n#{participant_phone.full_number}\n#{sms_plan.no_formula_text}"
          end

          it_behaves_like 'correct sms job queue'
        end

        context 'when first_name is missing' do
          let!(:participant) { create(:user, :participant, :confirmed, first_name: nil, last_name: 'Pitt', email: 'not.black.sabbath1@gmail.com') }
          let!(:participant_phone) { create(:phone, :confirmed, user: participant) }
          let!(:user_session) { create(:user_session, user: participant, session: session) }
          let!(:content) do
            "First name not provided\n#{participant.last_name}\n#{participant.email}\n#{participant_phone.full_number}\n#{sms_plan.no_formula_text}"
          end

          it_behaves_like 'correct sms job queue'
        end

        context 'when both last and first name are missing' do
          let!(:participant) { create(:user, :participant, :confirmed, last_name: nil, first_name: nil, email: 'not.black.sabbath1@gmail.com') }
          let!(:participant_phone) { create(:phone, :confirmed, user: participant) }
          let!(:user_session) { create(:user_session, user: participant, session: session) }
          let!(:content) do
            "First name not provided\nLast name not provided\n#{participant.email}\n#{participant_phone.full_number}\n#{sms_plan.no_formula_text}"
          end

          it_behaves_like 'correct sms job queue'
        end

        context 'when phone number is missing' do
          let!(:participant) { create(:user, :participant, :confirmed, first_name: 'Randall', last_name: 'Pitt', email: 'not.black.sabbath1@gmail.com') }
          let!(:user_session) { create(:user_session, user: participant, session: session) }
          let!(:content) { "#{participant.full_name}\n#{participant.email}\nPhone number not provided\n#{sms_plan.no_formula_text}" }

          it_behaves_like 'correct sms job queue'
        end

        context 'when guest user' do
          let!(:user) { create(:user, :guest, first_name: nil, last_name: nil) }
          let!(:content) do
            "First name not provided\nLast name not provided\nE-mail not provided\n#{phone.full_number}\n#{sms_plan.no_formula_text}"
          end

          it_behaves_like 'correct sms job queue'
        end
      end
    end
  end
end
