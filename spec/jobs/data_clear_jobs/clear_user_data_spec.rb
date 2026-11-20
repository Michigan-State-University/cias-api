# frozen_string_literal: true

RSpec.describe DataClearJobs::ClearUserData, type: :job do
  context 'with an intervention holding participant data' do
    subject { described_class.perform_now(intervention.id) }

    let!(:intervention) do
      create(:intervention, :with_pdf_report, :with_conversations_transcript, :with_predefined_participants, user: create(:user, :researcher))
    end
    let!(:conversation) { create(:live_chat_conversation, intervention: intervention) }
    let!(:user_intervention1) { create(:user_intervention, intervention: intervention, user: create(:user, :participant, :confirmed)) }
    let!(:user_intervention2) { create(:user_intervention, intervention: intervention, user: create(:user, :guest, :confirmed)) }
    let!(:user_intervention3) { create(:user_intervention, intervention: intervention, user: intervention.predefined_users.sample) }

    before do
      ActiveJob::Base.queue_adapter = :test
    end

    it 'remove all attachments' do
      expect { subject }.to change(ActiveStorage::Attachment, :count).by(-2)
    end

    it 'create a notification' do
      expect { subject }.to change(Notification, :count).by(1)
    end

    it 'marks the intervention as having its sensitive data removed' do
      subject
      expect(intervention.reload.sensitive_data_removed?).to be(true)
    end

    it 'interventions return information that hasn\'t have attachments' do
      subject
      expect(intervention.reload.reports.any?).to be false
      expect(intervention.reload.conversations_transcript.attached?).to be false
    end

    it 'remove all user_interventions' do
      expect { subject }.to change(UserIntervention, :count).by(-3)
    end

    it 'remove all guests without any user_intervention' do
      user_id = user_intervention2.user.id
      subject
      expect(User.find_by(id: user_id)).to be_nil
    end

    it 'remove all predefined participants without any user_intervention' do
      user_id = user_intervention3.user.id
      subject
      expect(User.find_by(id: user_id)).to be_nil
    end

    it 'removes associated predefined user parameters' do
      predefined_user_parameter_id = user_intervention3.user.predefined_user_parameter.id
      subject
      expect(PredefinedUserParameter.find_by(id: predefined_user_parameter_id)).to be_nil
    end

    it 'participants are stay intact' do
      user_id = user_intervention1.user.id
      subject
      expect(User.find_by(id: user_id).present?).to be true
    end
  end

  describe 'scheduled SMS campaigns' do
    let(:researcher) { create(:user, :researcher, :confirmed) }
    let!(:intervention) { create(:intervention, :published, user: researcher) }
    let!(:other_intervention) { create(:intervention, :published, user: researcher) }

    let!(:scheduled_invitation) { create(:pdp_sms_campaign, :scheduled, intervention: intervention, kind: 'invitation', scheduled_at: 2.days.from_now) }
    let!(:scheduled_manual) { create(:pdp_sms_campaign, :scheduled, intervention: intervention, kind: 'manual_reminder', scheduled_at: 3.days.from_now) }
    let!(:sent_campaign) { create(:pdp_sms_campaign, :scheduled, intervention: intervention, kind: 'invitation', status: 'sent', sent_at: 1.day.ago) }
    let!(:foreign_campaign) { create(:pdp_sms_campaign, :scheduled, intervention: other_intervention, scheduled_at: 2.days.from_now) }

    let!(:child_reminder) do
      create(:pdp_sms_campaign, :scheduled, intervention: intervention, kind: 'scheduled_reminder', parent_campaign: sent_campaign,
                                            days_after: 3, scheduled_at: 3.days.from_now)
    end

    after { delete_pushed_jobs }

    def cancel_service
      V1::PredefinedParticipants::SmsCampaigns::CancelService
    end

    describe 'cancels every scheduled campaign of the intervention' do
      it 'moves all scheduled campaigns (every kind) of the intervention to cancelled' do
        described_class.perform_now(intervention.id)

        expect([scheduled_invitation, scheduled_manual, child_reminder].map { |c| c.reload.status }).to all(eq('cancelled'))
      end

      it 'leaves campaigns that are not scheduled alone' do
        described_class.perform_now(intervention.id)
        expect(sent_campaign.reload.status).to eq('sent')
      end

      it 'leaves the campaigns of another intervention alone (the scope is the intervention)' do
        described_class.perform_now(intervention.id)
        expect(foreign_campaign.reload.status).to eq('scheduled')
      end

      it 'removes the scheduled Sidekiq jobs of those campaigns and keeps the job of another intervention' do
        jids = [scheduled_invitation, scheduled_manual, child_reminder].map { |c| push_campaign_job(c.id) }
        foreign_jid = push_campaign_job(foreign_campaign.id)

        described_class.perform_now(intervention.id)

        expect(jids.map { |jid| jid_scheduled?(jid) }).to all(be(false))
        expect(jid_scheduled?(foreign_jid)).to be(true)
      end

      it 'keeps the existing V1::SmsPlans::CancelScheduledSmses call' do
        allow(V1::SmsPlans::CancelScheduledSmses).to receive(:call).and_call_original
        described_class.perform_now(intervention.id)
        expect(V1::SmsPlans::CancelScheduledSmses).to have_received(:call).with(intervention.id)
      end

      it 'still completes the clearing (notification created, data marked removed)' do
        expect { described_class.perform_now(intervention.id) }.to change(Notification, :count).by(1)
        expect(intervention.reload.sensitive_data_removed?).to be(true)
      end

      it 'does not enqueue a retry for an intervention without any campaign' do
        other_intervention.sms_campaigns.destroy_all

        expect { described_class.perform_now(other_intervention.id) }
          .not_to have_enqueued_job(described_class)
      end
    end

    describe 'the cancel call is outside the transaction' do
      let(:jids) { [scheduled_invitation, scheduled_manual].map { |c| push_campaign_job(c.id) } }

      context 'when the clearing fails inside the transaction after the point where cancelling used to happen' do
        before do
          jids
          allow(Notification).to receive(:create!).and_raise(RuntimeError, 'CIAS_TDD_injected_failure')
        end

        it 'raises the injected failure (the transaction is rolled back)' do
          expect { described_class.new.perform(intervention.id) }.to raise_error(RuntimeError, 'CIAS_TDD_injected_failure')
        end

        it 'leaves the campaign statuses scheduled — no divergence with Redis — and a later successful run cancels them' do
          expect { described_class.new.perform(intervention.id) }.to raise_error(RuntimeError)
          expect([scheduled_invitation, scheduled_manual].map { |c| c.reload.status }).to all(eq('scheduled'))

          allow(Notification).to receive(:create!).and_call_original
          described_class.new.perform(intervention.id)
          expect([scheduled_invitation, scheduled_manual].map { |c| c.reload.status }).to all(eq('cancelled'))
        end

        it 'leaves the Sidekiq jobs in the ScheduledSet after the failed run, and a later successful run deletes them' do
          expect { described_class.new.perform(intervention.id) }.to raise_error(RuntimeError)
          expect(jids.map { |jid| jid_scheduled?(jid) }).to all(be(true))

          allow(Notification).to receive(:create!).and_call_original
          described_class.new.perform(intervention.id)
          expect(jids.map { |jid| jid_scheduled?(jid) }).to all(be(false))
        end
      end

      it 'calling the service inside a transaction that rolls back DOES diverge (so the test above is able to fail)' do
        jid = push_campaign_job(scheduled_invitation.id)

        ActiveRecord::Base.transaction do
          cancel_service.call(scheduled_invitation)
          raise ActiveRecord::Rollback
        end

        expect(scheduled_invitation.reload.status).to eq('scheduled')
        expect(jid_scheduled?(jid)).to be(false)
      end

      context 'when the clearing fails inside the transaction (divergence predicate)' do
        let(:scheduled_campaigns) { [scheduled_invitation, scheduled_manual, child_reminder] }

        before { scheduled_campaigns.each { |campaign| push_campaign_job(campaign.id) } }

        def divergent?(campaign)
          campaign.reload.status.eql?('scheduled') && !campaign_job_scheduled?(campaign.id)
        end

        it 'a failure inside the transaction leaves database and Redis consistent for every campaign' do
          allow(Notification).to receive(:create!).and_raise(RuntimeError, 'boom inside the transaction')

          described_class.perform_now(intervention.id)

          scheduled_campaigns.each { |campaign| expect(divergent?(campaign)).to be(false), "campaign #{campaign.kind} diverged" }
          allow(Notification).to receive(:create!).and_call_original
          described_class.perform_now(intervention.id)
          scheduled_campaigns.each do |campaign|
            expect(campaign.reload.status).to eq('cancelled')
            expect(campaign_job_scheduled?(campaign.id)).to be(false)
          end
        end
      end
    end
  end

  describe 'SMS links' do
    include ActiveSupport::Testing::TimeHelpers

    before { ActiveJob::Base.queue_adapter = :test }

    describe 'participant with an sms_links_users row' do
      let(:intervention) { create(:intervention, :with_predefined_participants, user: create(:user, :researcher)) }
      let(:participant) { intervention.predefined_users.first }
      let!(:join) { create(:sms_links_user, user: participant) }

      it 'does not fail and schedule a retry because of a foreign key violation' do
        expect { described_class.perform_now(intervention.id) }.not_to have_enqueued_job(described_class)
      end

      it 'removes the participant together with the join row' do
        participant_id = participant.id
        described_class.perform_now(intervention.id)

        expect(User.exists?(participant_id)).to be(false)
        expect(SmsLinksUser.exists?(join.id)).to be(false)
      end
    end

    describe 'pre-existing defect: participant reached by an SMS plan with a link' do
      let(:current_time) { Time.zone.parse('2021-07-20 20:02') }
      let(:intervention) { create(:intervention, :published, :with_predefined_participants, user: create(:user, :researcher)) }
      let(:participant) { intervention.predefined_users.first }
      let(:session) { create(:session, intervention: intervention) }
      let(:sms_plan) { create(:sms_plan, session: session, no_formula_text: 'CIAS_TDD_CANARY_BODY ::canary_link::') }
      let(:user_intervention) { create(:user_intervention, user: participant, intervention: intervention) }
      let(:user_session) { create(:user_session, session: session, user: participant, user_intervention: user_intervention) }

      before do
        travel_to(current_time)
        create(:phone, :confirmed, user: participant, iso: 'US', prefix: '+1', number: '2015550123')
        create(:sms_link, session: session, sms_plan: sms_plan, variable: 'canary_link', url: 'https://example.test/canary-target')
        V1::SmsPlans::ScheduleSmsForUserSession.call(user_session)
      end

      it 'already creates an sms_links_users row for the participant today' do
        expect(SmsLinksUser.where(user_id: participant.id).count).to eq(1)
      end

      it 'is cleared end to end without a foreign key violation' do
        participant_id = participant.id
        expect { described_class.perform_now(intervention.id) }.not_to have_enqueued_job(described_class)

        expect(User.exists?(participant_id)).to be(false)
        expect(SmsLinksUser.where(user_id: participant_id)).to be_empty
      end
    end
  end
end
