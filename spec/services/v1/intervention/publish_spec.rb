# frozen_string_literal: true

require 'rails_helper'
require 'support/scheduled_sms_helpers'

RSpec.describe V1::Intervention::Publish do
  context 'with scheduled sessions and preview data' do
    let!(:intervention) { create(:intervention, published_at: nil) }
    let!(:session) { create(:session, intervention: intervention) }
    let!(:session_with_autoclose) { create(:session, intervention: intervention, autoclose_enabled: true, autoclose_at: autoclose_at) }
    let!(:question_group) { create(:question_group, session: session) }
    let!(:question) { create(:question_single, question_group: question_group) }
    let!(:preview_session_user) { create(:user, :confirmed, :preview_session, preview_session_id: session.id) }
    let!(:user_intervention) { create(:user_intervention, intervention: intervention, user: preview_session_user) }
    let!(:user_session) { create(:user_session, user_id: preview_session_user.id, session_id: session.id, user_intervention: user_intervention) }
    let!(:answers) { create(:answer_single, question: question, user_session: user_session) }
    let!(:second_session) { create(:session, intervention: intervention, schedule: schedule, schedule_at: schedule_at, schedule_payload: schedule_payload) }
    let!(:third_session) { create(:session, intervention: intervention, schedule: 'days_after', schedule_payload: days_after_payload) }
    let(:schedule) { 'after_fill' }
    let(:schedule_at) { Date.current + 10.days }
    let(:autoclose_at) { Date.current + 20.days }
    let(:schedule_payload) { 7 }
    let(:days_after_payload) { 5 }
    let(:instance) { instance_double(described_class) }

    before do
      Timecop.freeze
      ActiveJob::Base.queue_adapter = :test
    end

    after do
      Timecop.return
    end

    context 'intervention status change publish' do
      it 'calls correct methods on execute' do
        allow(instance).to receive(:calculate_days_after_schedule)
        allow(instance).to receive(:timestamp_published_at)
        expect { described_class.new(intervention).execute }.not_to raise_error
      end

      it 'schedule autoclose jobs' do
        described_class.new(intervention).execute
        expect(SessionJobs::AutocloseSessionJob).to have_been_enqueued.at(autoclose_at).with(session_with_autoclose.id)
      end

      it 'sets correct publish at timestamp' do
        described_class.new(intervention).execute
        expect(intervention.reload.published_at.to_s).to eq(Time.current.to_s)
      end

      it 'correctly clears all test answers' do
        described_class.new(intervention).execute
        expect(intervention.sessions.first.question_groups.first.questions.first.answers.reload.size).to eq(0)
      end

      context 'when we have preview data' do
        let!(:preview_user_phone) { create(:phone, :confirmed, user: preview_session_user) }
        let!(:user_log_request) { create(:user_log_request, user: preview_session_user) }

        it 'clear preview users and preview user sessions' do
          described_class.new(intervention).execute
          expect(User.exists?(id: preview_session_user.id)).to be false
          expect(UserIntervention.exists?(id: user_session.id)).to be false
          expect(UserSession.exists?(id: user_session.id)).to be false
          expect(UserLogRequest.exists?(user_id: preview_session_user.id)).to be false
          expect(Phone.exists?(id: preview_user_phone.id)).to be false
        end
      end
    end

    context 'days after schedule calculation' do
      context 'previous session has after_fill schedule' do
        it 'correctly calculates schedule at for days after' do
          described_class.new(intervention).execute
          expect(third_session.reload.schedule_at).to eq(Date.current + days_after_payload.days)
        end

        context 'number of days equal nil' do
          let(:days_after_payload) { nil }

          it 'set default value' do
            described_class.new(intervention).execute
            expect(third_session.reload.schedule_at).to eq(Date.current)
          end
        end
      end

      context 'previous session has exact_date schedule' do
        let(:schedule) { 'exact_date' }

        it 'correctly calculates schedule at for days after' do
          described_class.new(intervention).execute
          expect(third_session.reload.schedule_at).to eq(schedule_at + days_after_payload.days)
        end

        context 'previous session has days_after_fill schedule' do
          let(:schedule) { 'days_after_fill' }

          it 'correctly calculates schedule at for days after' do
            described_class.new(intervention).execute
            expect(third_session.reload.schedule_at).to eq(Date.current + schedule_payload.days + days_after_payload.days)
          end
        end
      end
    end
  end

  describe '#auto_invitation' do
    include ActiveJob::TestHelper

    let!(:intervention) { create(:intervention, published_at: nil) }
    let!(:session) { create(:session, intervention: intervention) }

    before do
      ActionMailer::Base.deliveries.clear
      allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(true)
      allow(Sentry).to receive(:capture_exception)
    end

    def participant(**overrides)
      opts = { sms: true, email: true, phone: true, real_email: true, active: true, auto: true }.merge(overrides)
      user = create(:user, :confirmed, roles: %w[predefined_participant], email_autogenerated: !opts[:real_email])
      user.update_column(:active, false) unless opts[:active]
      create(:phone, user: user, **PhoneNumberFixtures::US_MAIN) if opts[:phone]
      PredefinedUserParameter.create!(user: user, intervention: intervention, auto_invitation: opts[:auto],
                                      sms_notification: opts[:sms], email_notification: opts[:email])
    end

    def publish
      described_class.new(intervention).execute
    end

    def parameter(record)
      PredefinedUserParameter.find(record.id)
    end

    def delivered_mail_count
      ActionMailer::Base.deliveries.size
    end

    describe 'publishing with an auto_invitation participant succeeds' do
      let!(:invited) { participant }

      it 'does not raise' do
        expect { publish }.not_to raise_error
      end

      it 'sends the SMS invitation' do
        expect { publish }.to change(Message, :count).by(1)
        expect(parameter(invited).sms_invitation_sent_at).to be_present
      end

      it 'sends the e-mail invitation' do
        expect { publish }.to change { delivered_mail_count }.by(1)
        expect(parameter(invited).email_invitation_sent_at).to be_present
      end

      it 'runs through the publish job as well' do
        expect { Interventions::PublishJob.perform_now(intervention.id) }.not_to raise_error
        expect(parameter(invited).sms_invitation_sent_at).to be_present
      end
    end

    describe 'channel selection' do
      it 'sends nothing to a participant without auto_invitation' do
        record = participant(auto: false)
        expect { publish }.to avoid_changing(Message, :count).and avoid_changing { delivered_mail_count }
        expect(parameter(record)).to have_attributes(sms_invitation_sent_at: nil, email_invitation_sent_at: nil)
      end

      it 'skips the SMS when sms_notification is off and still sends the e-mail' do
        record = participant(sms: false)
        expect { publish }.to avoid_changing(Message, :count).and change { delivered_mail_count }.by(1)
        expect(parameter(record).sms_invitation_sent_at).to be_nil
      end

      it 'skips the e-mail when email_notification is off and still sends the SMS' do
        record = participant(email: false)
        expect { publish }.to change(Message, :count).by(1).and avoid_changing { delivered_mail_count }
        expect(parameter(record).email_invitation_sent_at).to be_nil
      end

      it 'skips the SMS when the participant has no phone' do
        record = participant(phone: false)
        expect { publish }.to avoid_changing(Message, :count).and change { delivered_mail_count }.by(1)
        expect(parameter(record).sms_invitation_sent_at).to be_nil
      end

      it 'skips the e-mail when the address is autogenerated' do
        record = participant(real_email: false)
        expect { publish }.to change(Message, :count).by(1).and avoid_changing { delivered_mail_count }
        expect(parameter(record).email_invitation_sent_at).to be_nil
      end
    end

    describe 'a failure for one participant does not stop the others' do
      let!(:first_inactive) { participant(active: false) }
      let!(:active_ones) { Array.new(2) { participant } }
      let!(:last_inactive) { participant(active: false) }

      it 'does not raise' do
        expect { publish }.not_to raise_error
      end

      it 'reports the ActiveRecordError to Sentry' do
        publish
        expect(Sentry).to have_received(:capture_exception).with(an_instance_of(ActiveRecord::ActiveRecordError)).at_least(:once)
      end

      it 'invites every active participant by SMS and e-mail' do
        publish
        active_ones.each do |record|
          expect(parameter(record)).to have_attributes(sms_invitation_sent_at: be_present, email_invitation_sent_at: be_present)
        end
      end

      it 'invites nobody among the inactive ones' do
        publish
        [first_inactive, last_inactive].each do |record|
          expect(parameter(record)).to have_attributes(sms_invitation_sent_at: nil, email_invitation_sent_at: nil)
        end
      end

      it 'keeps published_at' do
        publish
        expect(intervention.reload.published_at).to be_present
      end

      it 'sends exactly one SMS per active participant' do
        expect { publish }.to change(Message, :count).by(2)
      end
    end

    describe 'invitations leave the publishing transaction before anything is sent or enqueued' do
      it 'sends, mails and enqueues at the transaction depth the caller started with' do
        participant
        baseline = ActiveRecord::Base.connection.open_transactions
        sms_depths = []
        allow_any_instance_of(Communication::Sms).to receive(:send_message) do
          sms_depths << ActiveRecord::Base.connection.open_transactions
          true
        end
        other_depths = []
        subscriber = ActiveSupport::Notifications.subscribe(/\A(enqueue\.active_job|deliver\.action_mailer)\z/) do
          other_depths << ActiveRecord::Base.connection.open_transactions
        end

        publish

        ActiveSupport::Notifications.unsubscribe(subscriber)
        expect(sms_depths).not_to be_empty
        expect(other_depths).not_to be_empty
        expect(sms_depths + other_depths).to all(eq(baseline))
      end
    end
  end

  describe 'predefined participant invitations' do
    subject(:publish) { described_class.new(intervention).execute }

    let!(:intervention) { create(:intervention, published_at: nil) }
    let!(:session) { create(:session, intervention: intervention) }
    let(:sequence_counter) { Enumerator.new { |y| (1..).each { |n| y << n } } }

    before do
      ActiveJob::Base.queue_adapter = :test
      ActionMailer::Base.deliveries.clear
      allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(true)
      allow(Sentry).to receive(:capture_exception)
    end

    def participant(**overrides)
      opts = { auto_invitation: true, sms: true, email: true, with_phone: true, real_email: true, active: true }
             .merge(overrides)
      n = sequence_counter.next
      attrs = if opts[:real_email]
                { email_autogenerated: false, email: "pdp_#{SecureRandom.hex(4)}_#{n}@example.test" }
              else
                {}
              end
      create(:user, :predefined_participant, :confirmed, **attrs).tap do |user|
        user.predefined_user_parameter.update!(intervention: intervention, auto_invitation: opts[:auto_invitation],
                                               sms_notification: opts[:sms], email_notification: opts[:email])
        create(:phone, user: user) if opts[:with_phone]
        user.update!(active: false) unless opts[:active]
      end
    end

    def pup_of(user)
      user.predefined_user_parameter.reload
    end

    describe 'publishing with an auto_invitation participant' do
      it 'sends the SMS invitation to an sms_notification participant with a phone' do
        user = participant(email: false)
        expect { publish }.to change(Message, :count).by(1)
        expect(pup_of(user).sms_invitation_sent_at).to be_present
      end

      it 'sends the e-mail invitation to an email_notification participant with a real e-mail' do
        user = participant(sms: false, with_phone: false)
        expect { publish }.to change { ActionMailer::Base.deliveries.size }.by(1)
        expect(pup_of(user).email_invitation_sent_at).to be_present
      end

      it 'does not send SMS when sms_notification is off' do
        user = participant(sms: false, email: false)
        expect { publish }.to avoid_changing(Message, :count)
        expect(pup_of(user).sms_invitation_sent_at).to be_nil
      end

      it 'does not send e-mail when email_notification is off' do
        user = participant(sms: false, email: false, with_phone: false)
        expect { publish }.to avoid_changing { ActionMailer::Base.deliveries.size }
        expect(pup_of(user).email_invitation_sent_at).to be_nil
      end

      it 'does not send SMS to a participant without a phone' do
        user = participant(email: false, with_phone: false)
        expect { publish }.to avoid_changing(Message, :count)
        expect(pup_of(user).sms_invitation_sent_at).to be_nil
      end

      it 'does not send e-mail to a participant with an autogenerated address' do
        user = participant(sms: false, with_phone: false, real_email: false)
        expect { publish }.to avoid_changing { ActionMailer::Base.deliveries.size }
        expect(pup_of(user).email_invitation_sent_at).to be_nil
      end

      it 'sends only to flagged participants when several are present' do
        invited = participant(email: false)
        skipped = participant(auto_invitation: false, email: false)
        publish
        expect(pup_of(invited).sms_invitation_sent_at).to be_present
        expect(pup_of(skipped).sms_invitation_sent_at).to be_nil
      end
    end

    describe 'one failing participant does not stop the rest' do
      let!(:inactive_users) { Array.new(2) { participant(email: false, active: false) } }
      let!(:active_users) { Array.new(2) { participant(email: false) } }

      it 'does not raise for an inactive participant' do
        expect { publish }.not_to raise_error
      end

      it 'invites every active participant' do
        publish
        expect(active_users.map { |u| pup_of(u).sms_invitation_sent_at }).to all(be_present)
      end

      it 'does not stamp an inactive participant as invited' do
        publish
        expect(inactive_users.map { |u| pup_of(u).sms_invitation_sent_at }).to all(be_nil)
      end

      it 'reports each failure to Sentry as an ActiveRecordError' do
        publish
        expect(Sentry).to have_received(:capture_exception).with(an_instance_of(ActiveRecord::ActiveRecordError)).exactly(2).times
      end

      it 'still schedules autoclose after a participant failed' do
        create(:session, intervention: intervention, autoclose_enabled: true, autoclose_at: 20.days.from_now)
        publish
        expect(SessionJobs::AutocloseSessionJob).to have_been_enqueued
      end
    end

    describe 'invitations go out outside any publishing transaction' do
      it 'sends the SMS at the same transaction depth as the surrounding example' do
        participant(email: false)
        baseline = ActiveRecord::Base.connection.open_transactions
        depths = []
        allow_any_instance_of(Communication::Sms).to receive(:send_message) do
          depths << ActiveRecord::Base.connection.open_transactions
          true
        end
        publish
        expect(depths).to eq([baseline])
      end

      it 'enqueues jobs at the same transaction depth as the surrounding example' do
        participant(email: false)
        create(:session, intervention: intervention, autoclose_enabled: true, autoclose_at: 20.days.from_now)
        baseline = ActiveRecord::Base.connection.open_transactions
        depths = []
        subscriber = ActiveSupport::Notifications.subscribe(/\A(enqueue|enqueue_at)\.active_job\z/) do
          depths << ActiveRecord::Base.connection.open_transactions
        end
        publish
        ActiveSupport::Notifications.unsubscribe(subscriber)
        expect(depths).not_to be_empty
        expect(depths).to all(eq(baseline))
      end
    end
  end

  describe 'opted-out and SMS-ineligible participants' do
    include ScheduledSmsHelpers

    let(:intervention) { create(:intervention, published_at: nil) }
    let!(:sms_calls) { stub_sms_provider }

    before do
      ActiveJob::Base.queue_adapter = :test
      stub_scheduled_set([])
    end

    def participant(sms_notification: true, auto_invitation: true, eligible: true)
      user = create(:user, :predefined_participant, :confirmed)
      user.predefined_user_parameter.update!(intervention_id: intervention.id, sms_notification: sms_notification,
                                             auto_invitation: auto_invitation)
      phone = create(:phone, :confirmed, user: user)
      phone.update_column(:sms_eligible, false) unless eligible
      user
    end

    def publish!
      described_class.new(intervention).execute
    end

    it 'an eligible participant who is not opted out receives the invitation' do
      user = participant
      expect { publish! }.to change(Message, :count).by(1)
      expect(user.predefined_user_parameter.reload.sms_invitation_sent_at).to be_present
    end

    it 'an opted-out participant gets no Message' do
      create(:pdp_sms_opt_out, user: participant)
      expect { publish! }.not_to change(Message, :count)
    end

    it 'an opted-out participant does not reach the SMS provider' do
      create(:pdp_sms_opt_out, user: participant)
      publish!
      expect(sms_calls).to be_empty
    end

    it 'an opted-out participant is not stamped as invited' do
      user = participant
      create(:pdp_sms_opt_out, user: user)
      publish!
      expect(user.predefined_user_parameter.reload.sms_invitation_sent_at).to be_nil
    end

    it 'a number that is not sms_eligible gets no Message' do
      participant(eligible: false)
      expect { publish! }.not_to change(Message, :count)
    end

    it 'a number that is not sms_eligible does not reach the provider and is not stamped' do
      user = participant(eligible: false)
      publish!
      expect([sms_calls.size, user.predefined_user_parameter.reload.sms_invitation_sent_at]).to eq([0, nil])
    end

    it 'the filter is per participant: others in the same intervention are still invited' do
      opted_out = participant
      create(:pdp_sms_opt_out, user: opted_out)
      participant(eligible: false)
      ok_user = participant
      publish!
      expect([Message.count, ok_user.predefined_user_parameter.reload.sms_invitation_sent_at.present?]).to eq([1, true])
    end

    it 'publishing still completes when every recipient is filtered out' do
      create(:pdp_sms_opt_out, user: participant)
      publish!
      expect(intervention.reload.published_at).to be_present
    end

    it 'after START (opt-out removed) the participant is invited again' do
      user = participant
      create(:pdp_sms_opt_out, user: user).destroy!
      expect { publish! }.to change(Message, :count).by(1)
    end

    it 'sms_notification false is still not invited' do
      participant(sms_notification: false)
      expect { publish! }.not_to change(Message, :count)
    end

    it 'auto_invitation false is still not invited (preserved)' do
      participant(auto_invitation: false)
      expect { publish! }.not_to change(Message, :count)
    end
  end
end
