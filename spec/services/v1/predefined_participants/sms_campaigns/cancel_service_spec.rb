# frozen_string_literal: true

# Redis is real and shared between test processes: never `clear`, delete only this file's campaign ids.
RSpec.describe 'V1::PredefinedParticipants::SmsCampaigns::CancelService' do
  let(:service) { cancel_service_class }
  let(:intervention) { create(:intervention, :published) }

  around { |example| with_real_sidekiq_for_campaign_job { example.run } }

  describe 'only a scheduled campaign can be cancelled' do
    it 'sets a scheduled campaign to cancelled' do
      campaign = create(:pdp_sms_campaign, :due_soon, intervention: intervention, status: 'scheduled')

      service.call(campaign)

      expect(campaign.reload.status).to eq('cancelled')
    end

    %w[sending sent failed cancelled skipped].each do |status|
      it "refuses a #{status} campaign with a conflict and leaves it unchanged" do
        campaign = create(:pdp_sms_campaign, :due_soon, intervention: intervention, status: status)
        enqueue_campaign_job_in_sidekiq(campaign)

        error = attempt_capturing_error { service.call(campaign) }

        expect(error).to be_a(ComplexException)
        expect(error.status_code).to eq(:conflict)
        expect(campaign.reload.status).to eq(status)
        expect(campaign_job_scheduled?(campaign.id)).to be(true)
      end
    end

    it 'does not touch the counters or timestamps of a refused campaign' do
      campaign = create(:pdp_sms_campaign, :due_soon, intervention: intervention, status: 'sent', sent_at: 1.day.ago, accepted_count: 3)
      before = campaign.reload.attributes

      attempt_capturing_error { service.call(campaign) }

      expect(campaign.reload.attributes).to eq(before)
    end
  end

  describe 'the database write is the authoritative act' do
    let(:parent) { create(:pdp_sms_campaign, :due_soon, intervention: intervention, kind: 'invitation', status: 'sending') }
    let(:child) do
      create(:pdp_sms_campaign, :due_soon, intervention: intervention, kind: 'scheduled_reminder', days_after: 3, parent_campaign: parent,
                                           status: 'scheduled', scheduled_at: 3.days.from_now)
    end

    it 'cancels a child reminder the parent job has not enqueued yet, although there is nothing to find in the ScheduledSet' do
      expect(campaign_job_scheduled?(child.id)).to be(false)

      expect { service.call(child) }.not_to raise_error

      expect(child.reload.status).to eq('cancelled')
      expect(parent.reload.status).to eq('sending')
    end

    it 'does not touch the parent when only the child is cancelled' do
      service.call(child)
      expect(parent.reload.status).to eq('sending')
    end

    it 'keeps the campaign cancelled even when the Sidekiq scan itself fails (best effort)' do
      allow(Sidekiq::ScheduledSet).to receive(:new).and_raise(RedisClient::CannotConnectError, 'redis down')

      attempt_capturing_error { service.call(child) }

      expect(child.reload.status).to eq('cancelled')
    end
  end

  describe 'the scan removes the job of this campaign and only of this campaign' do
    it 'deletes the scheduled job of the cancelled campaign and keeps the job of another campaign' do
      cancelled = create(:pdp_sms_campaign, :due_soon, intervention: intervention, kind: 'manual_reminder', status: 'scheduled')
      untouched = create(:pdp_sms_campaign, :due_soon, intervention: intervention, kind: 'invitation', status: 'scheduled')
      enqueue_campaign_job_in_sidekiq(cancelled)
      enqueue_campaign_job_in_sidekiq(untouched)
      expect(campaign_job_scheduled?(cancelled.id)).to be(true)
      expect(campaign_job_scheduled?(untouched.id)).to be(true)

      service.call(cancelled)

      expect(campaign_job_scheduled?(cancelled.id)).to be(false)
      # Guards against a matcher that hits nothing or deletes everything.
      expect(campaign_job_scheduled?(untouched.id)).to be(true)
      expect(untouched.reload.status).to eq('scheduled')
    end
  end

  describe 'the job is matched by arguments[0], not arguments[5]' do
    let(:campaign) { create(:pdp_sms_campaign, :due_soon, intervention: intervention, status: 'scheduled') }

    it 'deletes the entry whose first argument is the campaign id and keeps an entry carrying the id at position 5' do
      enqueue_campaign_job_in_sidekiq(campaign)
      push_decoy_job_with_campaign_id_at_position5(campaign)
      expect(scheduled_entries_with_arguments(campaign.id).size).to eq(2)

      service.call(campaign)

      remaining = scheduled_entries_with_arguments(campaign.id)
      expect(remaining.size).to eq(1)
      expect(remaining.first.args.first['arguments'][5]).to eq(campaign.id)
      expect(campaign_job_scheduled?(campaign.id)).to be(false)
    end

    it 'keeps a scheduled job of a different class that happens to carry the campaign id first' do
      enqueue_campaign_job_in_sidekiq(campaign)
      push_foreign_class_job(campaign)

      service.call(campaign)

      expect(campaign_job_scheduled?(campaign.id)).to be(false)
      expect(scheduled_entry_present?(job_class_name: 'SmsPlans::SendSmsJob', first_argument: campaign.id)).to be(true)
    end

    it 'deletes a job entry that is a campaign id at arguments[0] even when extra arguments follow it' do
      enqueue_campaign_job_in_sidekiq(campaign, nil, nil)

      service.call(campaign)

      expect(campaign_job_scheduled?(campaign.id)).to be(false)
    end
  end
end
