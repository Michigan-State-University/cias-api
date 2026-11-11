# frozen_string_literal: true

require 'rails_helper'
require 'support/scheduled_sms_helpers'

RSpec.describe V1::Sms::Replay do
  context 'with ActiveJob test helpers' do
    include ActiveJob::TestHelper

    subject { described_class.call(from, to, body) }

    let!(:user) { create(:user, :confirmed, :participant) }
    let(:from) { '+48555777888' }
    let(:to) { '+48555444777' }

    context 'sending STOP message' do
      let(:body) { 'STOP' }
      let!(:session) { create(:session) }

      before do
        10.times do |delay|
          SmsPlans::SendSmsJob.set(wait_until: (delay + 1).days.from_now).perform_later(from, 'example content', nil, user.id, false, session.id)
        end
      end

      it 'call the method to clear jobs' do
        expect_any_instance_of(described_class).to receive(:delete_messaged_for).with(from)
        subject
      end

      context 'stop with white spaces' do
        let(:body) { ' stop ' }

        it 'call the method to clear jobs' do
          expect_any_instance_of(described_class).to receive(:delete_messaged_for).with(from)
          subject
        end
      end

      context 'body different than stop' do
        let(:body) { ' help ' }

        it 'call the method to clear jobs' do
          expect_any_instance_of(described_class).not_to receive(:delete_messaged_for).with(from)
          subject
        end
      end

      %w[STOPALL unsubscribe Cancel quit OPTOUT revoke].each do |keyword|
        context "with the #{keyword} opt-out keyword" do
          let(:body) { keyword }

          it 'clears jobs' do
            expect_any_instance_of(described_class).to receive(:delete_messaged_for).with(from)
            subject
          end
        end
      end

      ['Please do not stop', 'I will stop by later', 'nonstop', 'UNSTOP'].each do |text|
        context "with #{text.inspect}" do
          let(:body) { text }

          it 'does not clear jobs' do
            expect_any_instance_of(described_class).not_to receive(:delete_messaged_for)
            subject
          end
        end
      end
    end

    context 'sending text, which matches sms_code of session' do
      context 'when session session code has proper length' do
        let(:body) { 'SMS_CODE' }

        it 'creates new user session' do
          expect_any_instance_of(described_class).to receive(:handle_message_with_sms_code)
          subject
        end
      end

      context 'when session session code does not have proper length' do
        let(:body) { 'SMS' }

        it 'does not create new user session' do
          expect_any_instance_of(described_class).not_to receive(:handle_message_with_sms_code)
          subject
        end
      end
    end

    %w[YES END].each do |answer|
      context "when a pending SMS question accepts #{answer}" do
        let!(:user) { create(:user, :with_phone, pending_sms_answer: true) }
        let(:from) { user.phone.full_number }
        let(:body) { answer }
        let!(:intervention) { create(:intervention) }
        let!(:session) do
          create(:sms_session, sms_codes: [build(:sms_code, sms_code: 'SMS_CODE_1')], intervention: intervention,
                               question_group_initial: build(:question_group_initial))
        end
        let!(:question_group) { create(:sms_question_group, session: session) }
        let!(:question) { create(:question_sms, question_group: question_group, accepted_answers: { predefined: [answer, 'NO'] }) }
        let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
        let!(:user_session) { create(:sms_user_session, user: user, session: session, current_question_id: question.id) }

        before { allow(V1::AnswerService).to receive(:call) }

        it "records #{answer} as the answer" do
          subject
          expect(V1::AnswerService).to have_received(:call).with(user, user_session.id, question.id, hash_including(type: 'Answer::Sms'))
        end

        it 'does not opt the user out' do
          subject
          expect(SmsOptOut.where(user_id: user.id)).to be_empty
        end
      end
    end

    describe '#schedule_or_finish' do
      let(:intervention) { create(:intervention) }
      let(:session) { create(:sms_session, intervention: intervention) }
      let(:question_group_initial) do
        create(:question_group_initial, session: session, sms_schedule: {
                 'number_of_repetitions' => 3,
                 'messages_after_limit' => 5
               })
      end
      let(:question) { create(:question_sms_information, question_group: question_group_initial) }
      let(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
      let(:replay_service) { described_class.new(from, to, 'test message') }

      context 'when it was the last question in user session' do
        let(:user_session) do
          create(:sms_user_session, user: user, session: session, user_intervention: user_intervention,
                                    number_of_repetitions: 3, max_repetitions_reached_at: 1.day.ago)
        end

        before do
          questions = create_list(:question_sms_information, 7, question_group: question_group_initial)
          questions.each do |q|
            create(:message, :with_code, question: q, created_at: 12.hours.ago)
          end
        end

        it 'finishes the user session' do
          expect do
            replay_service.send(:schedule_or_finish, user_session)
          end.to change { user_session.reload.finished_at }.from(nil)
        end
      end

      context 'when it was not the last question in user session' do
        let(:user_session) do
          create(:sms_user_session, user: user, session: session, user_intervention: user_intervention,
                                    number_of_repetitions: 2)
        end

        it 'does not finish the user session' do
          expect do
            replay_service.send(:schedule_or_finish, user_session)
          end.not_to change { user_session.reload.finished_at }
        end
      end

      context 'when repetitions reached but messages under limit' do
        let(:user_session) do
          create(:sms_user_session, user: user, session: session, user_intervention: user_intervention,
                                    number_of_repetitions: 3, max_repetitions_reached_at: 1.day.ago)
        end

        before do
          questions = create_list(:question_sms_information, 3, question_group: question_group_initial)
          questions.each do |q|
            create(:message, :with_code, question: q, created_at: 12.hours.ago)
          end
        end

        it 'does not finish the user session' do
          expect do
            replay_service.send(:schedule_or_finish, user_session)
          end.not_to change { user_session.reload.finished_at }
        end
      end
    end

    describe 'FinishUserSessionHelper integration' do
      let(:intervention) { create(:intervention) }
      let(:session) { create(:sms_session, intervention: intervention) }
      let(:question_group_initial) do
        create(:question_group_initial, session: session)
      end
      let!(:question) { create(:question_sms_information, question_group: question_group_initial) }
      let(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }

      it 'includes FinishUserSessionHelper module' do
        expect(described_class.ancestors).to include(SmsCampaign::FinishUserSessionHelper)
      end

      context 'when repetitions reached and message limit reached' do
        let(:user_session) do
          create(:sms_user_session, user: user, session: session, user_intervention: user_intervention,
                                    number_of_repetitions: 3, max_repetitions_reached_at: 1.day.ago)
        end
        let(:replay_service) { described_class.new(from, to, 'test answer') }

        before do
          questions = create_list(:question_sms_information, 7, question_group: question_group_initial)
          questions.each do |q|
            create(:message, :with_code, question: q, created_at: 12.hours.ago)
          end
        end

        it 'finishes user session when conditions are met' do
          expect do
            replay_service.send(:schedule_or_finish, user_session)
          end.to change { user_session.reload.finished_at }.from(nil)
        end
      end

      context 'when repetitions not reached' do
        let(:user_session) do
          create(:sms_user_session, user: user, session: session, user_intervention: user_intervention,
                                    number_of_repetitions: 2)
        end
        let(:replay_service) { described_class.new(from, to, 'test answer') }

        it 'does not finish user session when repetitions not reached' do
          expect do
            replay_service.send(:schedule_or_finish, user_session)
          end.not_to change { user_session.reload.finished_at }
        end
      end
    end

    describe '#create_new_user_session! phone number tracking' do
      let(:intervention) { create(:intervention) }
      let(:session) { create(:sms_session, intervention: intervention) }
      let!(:sms_code) { create(:sms_code, session: session, sms_code: 'TESTCODE') }
      let(:body) { 'TESTCODE' }
      let(:from) { '+12015550123' }

      before do
        allow(SmsPlans::SendSmsJob).to receive(:perform_later)
      end

      context 'when creating a new user session for a new guest user' do
        it 'stores the phone number prefix on the user session' do
          expect { subject }.to change(UserSession::Sms, :count).by(1)

          user_session = UserSession::Sms.last
          expect(user_session.sms_phone_prefix).to eq('+1')
        end

        it 'stores the national phone number on the user session' do
          expect { subject }.to change(UserSession::Sms, :count).by(1)

          user_session = UserSession::Sms.last
          expect(user_session.sms_phone_number).to eq('2015550123')
        end

        it 'returns correct sms_full_number' do
          subject
          user_session = UserSession::Sms.last
          expect(user_session.sms_full_number).to eq('+12015550123')
        end
      end

      context 'when creating a new user session for existing user' do
        let!(:phone) { create(:phone, prefix: '+1', number: '2015550123', user: user, confirmed: true) }
        let!(:user_intervention_record) { create(:user_intervention, user: user, intervention: intervention) }

        it 'stores phone information on the user session' do
          expect { subject }.to change(UserSession::Sms, :count).by(1)

          user_session = UserSession::Sms.last
          expect(user_session.sms_phone_prefix).to eq('+1')
          expect(user_session.sms_phone_number).to eq('2015550123')
          expect(user_session.sms_full_number).to eq('+12015550123')
        end
      end

      context 'with international phone numbers' do
        let(:from) { '+48555777888' }

        it 'handles Polish phone numbers correctly' do
          expect { subject }.to change(UserSession::Sms, :count).by(1)

          user_session = UserSession::Sms.last
          expect(user_session.sms_phone_prefix).to eq('+48')
          expect(user_session.sms_phone_number).to eq('555777888')
          expect(user_session.sms_full_number).to eq('+48555777888')
        end
      end
    end
  end

  describe 'STOP and START opt-out keywords' do
    include ActiveSupport::Testing::TimeHelpers
    include ScheduledSmsHelpers

    subject(:call_replay) { described_class.call(from, to, body) }

    let(:to) { '+12015550130' }
    let!(:user) { create(:user, :confirmed, :participant) }
    let!(:phone) { create(:phone, :confirmed, user: user) }
    let(:from) { phone.full_number }
    let(:fake_jobs) { [] }

    before { stub_scheduled_set(fake_jobs) }

    def opt_out_for(target)
      SmsOptOut.find_by(user_id: target.id)
    end

    describe 'STOP' do
      let(:body) { 'STOP' }

      it 'creates exactly one SmsOptOut row for the user found by the incoming number' do
        expect { call_replay }.to change { SmsOptOut.where(user_id: user.id).count }.from(0).to(1)
      end

      it 'stamps opted_out_at with the time of the message' do
        travel_to(Time.zone.local(2026, 11, 1, 12, 0, 0)) do
          call_replay
          expect(opt_out_for(user).opted_out_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'does not create a row for a different user' do
        other = create(:user, :confirmed, :participant)
        create(:phone, :confirmed, user: other)
        call_replay
        expect(SmsOptOut.where(user_id: other.id)).to be_empty
      end

      it 'a repeated STOP does not raise and keeps a single row (unique per user)' do
        described_class.call(from, to, 'STOP')
        expect { described_class.call(from, to, 'STOP') }.not_to raise_error
        expect(SmsOptOut.where(user_id: user.id).count).to eq(1)
      end

      it 'a repeated STOP keeps the original opted_out_at' do
        first_time = Time.zone.local(2026, 11, 1, 12, 0, 0)
        travel_to(first_time) { described_class.call(from, to, 'STOP') }
        travel_to(first_time + 3.days) { described_class.call(from, to, 'STOP') }
        expect(opt_out_for(user).opted_out_at).to be_within(1.second).of(first_time)
      end

      context 'with surrounding white space and lowercase' do
        let(:body) { '  stop ' }

        it 'still creates the opt-out' do
          expect { call_replay }.to change { SmsOptOut.where(user_id: user.id).count }.from(0).to(1)
        end
      end

      it 'still returns a TwiML response' do
        expect(call_replay).to be_a(Twilio::TwiML::MessagingResponse)
      end

      it 'keeps deleting the queued SmsPlans::SendSmsJob for the number' do
        job = fake_send_sms_job_for(from)
        fake_jobs << job
        call_replay
        expect(job).to be_deleted
      end
    end

    describe 'STOP matches the whole message, not a substring' do
      ['STOP NOW', 'please stop', 'stop texting me', 'I will stop by later', 'stopping', 'nonstop',
       'please do not stop', 'STOP ME NOT', 'UNSTOP', 'stop please', 'nonstop.', 'UNSTOP!'].each do |text|
        context "with #{text.inspect}" do
          let(:body) { text }

          it 'does not create an SmsOptOut' do
            call_replay
            expect(SmsOptOut.where(user_id: user.id)).to be_empty
          end

          it 'keeps the queued SmsPlans::SendSmsJob' do
            job = fake_send_sms_job_for(from)
            fake_jobs << job
            call_replay
            expect(job).not_to be_deleted
          end
        end
      end
    end

    describe 'opt-out keyword surrounded by punctuation' do
      ['STOP.', 'Stop!', 'STOP!!', '"stop"', ' Quit. '].each do |text|
        context "with #{text.inspect}" do
          let(:body) { text }

          before { allow(SmsPlans::SendSmsJob).to receive(:perform_later) }

          it 'creates an SmsOptOut' do
            expect { call_replay }.to change { SmsOptOut.where(user_id: user.id).count }.from(0).to(1)
          end

          it 'does not answer with an SMS' do
            call_replay
            expect(SmsPlans::SendSmsJob).not_to have_received(:perform_later)
          end

          it 'deletes the queued SmsPlans::SendSmsJob' do
            job = fake_send_sms_job_for(from)
            fake_jobs << job
            call_replay
            expect(job).to be_deleted
          end
        end
      end
    end

    describe 'opt-in keyword surrounded by punctuation' do
      ['START.', 'Start!', 'unstop?'].each do |text|
        context "with #{text.inspect}" do
          let(:body) { text }

          before { allow(SmsPlans::SendSmsJob).to receive(:perform_later) }

          it 'deletes the SmsOptOut row of the user' do
            create(:pdp_sms_opt_out, user: user)
            expect { call_replay }.to change { SmsOptOut.where(user_id: user.id).count }.from(1).to(0)
          end

          it 'does not answer with an SMS' do
            call_replay
            expect(SmsPlans::SendSmsJob).not_to have_received(:perform_later)
          end
        end
      end
    end

    describe 'other opt-out keywords' do
      %w[STOPALL UNSUBSCRIBE CANCEL QUIT OPTOUT REVOKE].each do |keyword|
        context "with #{keyword.inspect}" do
          let(:body) { " #{keyword.downcase} " }

          it 'creates an SmsOptOut' do
            expect { call_replay }.to change { SmsOptOut.where(user_id: user.id).count }.from(0).to(1)
          end

          it 'deletes the queued SmsPlans::SendSmsJob' do
            job = fake_send_sms_job_for(from)
            fake_jobs << job
            call_replay
            expect(job).to be_deleted
          end
        end
      end
    end

    describe 'UNSTOP' do
      let(:body) { 'unstop' }

      it 'deletes the SmsOptOut row of the user' do
        create(:pdp_sms_opt_out, user: user)
        expect { call_replay }.to change { SmsOptOut.where(user_id: user.id).count }.from(1).to(0)
      end
    end

    describe 'START' do
      let(:body) { 'START' }

      it 'deletes the SmsOptOut row of the user' do
        create(:pdp_sms_opt_out, user: user)
        expect { call_replay }.to change { SmsOptOut.where(user_id: user.id).count }.from(1).to(0)
      end

      it 'leaves other users opted out' do
        other = create(:user, :confirmed, :participant)
        create(:phone, :confirmed, user: other)
        create(:pdp_sms_opt_out, user: other)
        create(:pdp_sms_opt_out, user: user)
        call_replay
        expect(SmsOptOut.where(user_id: other.id).count).to eq(1)
      end

      it 'does not raise when the user was not opted out' do
        expect { call_replay }.not_to raise_error
      end

      it 'works with lowercase and white space' do
        create(:pdp_sms_opt_out, user: user)
        expect { described_class.call(from, to, ' start ') }.to change { SmsOptOut.where(user_id: user.id).count }.from(1).to(0)
      end

      it 'does not delete queued jobs' do
        job = fake_send_sms_job_for(from)
        fake_jobs << job
        call_replay
        expect(job).not_to be_deleted
      end

      it 'STOP after START opts the user out again' do
        create(:pdp_sms_opt_out, user: user)
        described_class.call(from, to, 'START')
        described_class.call(from, to, 'STOP')
        expect(SmsOptOut.where(user_id: user.id).count).to eq(1)
      end
    end

    describe 'START matches the whole message, not a substring' do
      ['I will start tomorrow', 'restart', 'starting now', 'START OVER'].each do |text|
        context "with #{text.inspect}" do
          let(:body) { text }

          it 'keeps the existing SmsOptOut' do
            create(:pdp_sms_opt_out, user: user)
            call_replay
            expect(SmsOptOut.where(user_id: user.id).count).to eq(1)
          end
        end
      end
    end

    describe 'STOP from a number with a trunk prefix' do
      let(:body) { 'STOP' }
      let(:from) { '+447400123456' }
      let!(:phone) do
        Phone.new(user: user, iso: 'GB', prefix: '+44', number: '7400123456').tap { |stored| stored.save!(validate: false) }
      end

      it 'finds the user by the national number without the trunk prefix' do
        expect { call_replay }.to change { SmsOptOut.where(user_id: user.id).count }.from(0).to(1)
      end
    end

    describe 'STOP from a number that belongs to no user' do
      let(:body) { 'STOP' }
      let(:from) { '+12015550129' }

      it 'creates no SmsOptOut row' do
        expect { call_replay }.not_to change(SmsOptOut, :count)
      end

      it 'does not raise' do
        expect { call_replay }.not_to raise_error
      end

      it 'still deletes queued SmsPlans::SendSmsJob addressed to that number' do
        job = fake_send_sms_job_for(from)
        other_job = fake_send_sms_job_for('+12015550128')
        fake_jobs.push(job, other_job)
        call_replay
        expect([job.deleted?, other_job.deleted?]).to eq([true, false])
      end

      it 'does not create a row for any existing user' do
        expect { call_replay }.not_to change { SmsOptOut.where(user_id: user.id).count }
      end

      it 'returns a TwiML response' do
        expect(call_replay).to be_a(Twilio::TwiML::MessagingResponse)
      end
    end

    describe 'START from a number that belongs to no user' do
      let(:body) { 'START' }
      let(:from) { '+12015550129' }

      it 'does not raise and leaves existing opt-outs intact' do
        create(:pdp_sms_opt_out, user: user)
        expect { call_replay }.not_to change(SmsOptOut, :count)
      end
    end

    describe 'HELP' do
      let(:body) { 'HELP' }

      it 'returns an informational TwiML message' do
        expect(call_replay.to_s).to match(%r{<Message>\s*\S.*</Message>}m)
      end

      it 'does not create an SmsOptOut' do
        expect { call_replay }.not_to change(SmsOptOut, :count)
      end

      it 'does not delete an existing SmsOptOut' do
        create(:pdp_sms_opt_out, user: user)
        expect { call_replay }.not_to change { SmsOptOut.where(user_id: user.id).count }
      end

      it 'does not delete queued jobs' do
        job = fake_send_sms_job_for(from)
        fake_jobs << job
        call_replay
        expect(job).not_to be_deleted
      end

      it 'enqueues no job' do
        expect { call_replay }.not_to have_enqueued_job
      end

      it 'answers lowercase help with white space the same way' do
        expect(described_class.call(from, to, ' help ').to_s).to match(%r{<Message>\s*\S.*</Message>}m)
      end

      context 'when the number belongs to no user' do
        let(:from) { '+12015550129' }

        it 'still answers and changes no state' do
          expect { call_replay }.not_to change(SmsOptOut, :count)
          expect(call_replay.to_s).to match(%r{<Message>\s*\S.*</Message>}m)
        end
      end
    end
  end
end
