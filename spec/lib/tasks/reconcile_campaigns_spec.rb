# frozen_string_literal: true

RSpec.describe 'predefined_participants:reconcile_campaigns' do
  include ActiveSupport::Testing::TimeHelpers

  let(:task_name) { 'predefined_participants:reconcile_campaigns' }
  let(:job_class) { PredefinedParticipants::SendSmsCampaignJob }
  let(:now) { Time.utc(2026, 11, 2, 12, 0, 0) }
  let(:scheduled_at) { Time.utc(2026, 11, 2, 9, 0, 0) }
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let!(:intervention) { create(:intervention, :published, :with_predefined_participants, user: researcher) }

  let(:env_keys) { %w[DRY_RUN] }
  let(:original_env) { env_keys.index_with { |key| ENV.fetch(key, nil) } }

  before do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    original_env
    env_keys.each { |key| ENV.delete(key) }
    travel_to now
  end

  after do
    original_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def invoke
    task = Rake::Task[task_name]
    task.reenable
    silence_stdout { task.invoke }
  end

  def stranded_campaign(attrs = {})
    campaign = create(:pdp_sms_campaign, :scheduled, { intervention: create(:intervention, :published), scheduled_at: scheduled_at }.merge(attrs))
    campaign.update_columns(updated_at: now - 3.hours)
    campaign
  end

  # Runs, one by one, the campaign jobs the task enqueued (the global :test adapter only records them).
  def reconcile_and_run_jobs
    adapter = ActiveJob::Base.queue_adapter
    already = adapter.enqueued_jobs.size
    invoke
    adapter.enqueued_jobs.drop(already).select { |job| job[:job] == job_class }.each do |job|
      job_class.perform_now(*ActiveJob::Arguments.deserialize(job[:args]))
    end
  end

  describe 're-enqueue' do
    it 'enqueues the campaign job for a stranded scheduled campaign, on the sms_plans queue' do
      campaign = stranded_campaign
      expect { invoke }.to have_enqueued_job(job_class).with(campaign.id).on_queue('sms_plans')
    end

    it 'enqueues it with set(wait_until: scheduled_at) — NOT with perform_later (no :no_wait)' do
      campaign = stranded_campaign
      expect { invoke }.to have_enqueued_job(job_class).with(campaign.id).at(scheduled_at)
    end

    it 'covers a sending campaign that lost its run' do
      campaign = stranded_campaign(status: 'sending')
      expect { invoke }.to have_enqueued_job(job_class).with(campaign.id)
    end

    it 'covers every kind' do
      manual = stranded_campaign(kind: 'manual_reminder')
      parent = stranded_campaign(status: 'sent')
      child = stranded_campaign(kind: 'scheduled_reminder', parent_campaign: parent, intervention: parent.intervention, days_after: 3)

      expect { invoke }.to have_enqueued_job(job_class).with(manual.id).and have_enqueued_job(job_class).with(child.id)
    end

    it 'covers every kind, including a scheduled reminder whose parent has closed' do
      parent = stranded_campaign(status: 'sending', kind: 'invitation')
      parent.update_columns(status: 'sent', sent_at: now - 3.days)
      child = stranded_campaign(kind: 'scheduled_reminder', parent_campaign: parent, intervention: parent.intervention,
                                days_after: 3, scheduled_at: now - 1.day)

      expect { invoke }.to have_enqueued_job(job_class).with(child.id)
    end

    it 'does not fire a child reminder that is merely waiting for its future scheduled_at' do
      parent = stranded_campaign(status: 'sent')
      waiting = stranded_campaign(kind: 'scheduled_reminder', parent_campaign: parent, intervention: parent.intervention,
                                  days_after: 3, scheduled_at: now + 3.days)

      expect { invoke }.not_to have_enqueued_job(job_class).with(waiting.id)
    end

    it 'does not touch cancelled, sent, failed or skipped campaigns' do
      closed = %w[cancelled sent failed skipped].map { |status| stranded_campaign(status: status) }

      expect { invoke }.not_to have_enqueued_job(job_class)
      expect(closed.map { |c| c.reload.status }).to eq(%w[cancelled sent failed skipped])
    end

    it 'does not change the status of the campaigns it re-enqueues' do
      campaign = stranded_campaign(status: 'sending')
      invoke
      expect(campaign.reload.status).to eq('sending')
    end

    it 'enqueues nothing when nothing is stranded' do
      expect { invoke }.not_to have_enqueued_job(job_class)
    end
  end

  describe 'DRY_RUN' do
    let!(:campaign) { stranded_campaign }

    it 'DRY_RUN=1 previews and enqueues nothing' do
      ENV['DRY_RUN'] = '1'
      expect { invoke }.not_to have_enqueued_job(job_class)
    end

    it 'a present-but-empty DRY_RUN still previews (shell-eaten variable)' do
      ENV['DRY_RUN'] = ''
      expect { invoke }.not_to have_enqueued_job(job_class)
    end

    it 'an explicit falsey DRY_RUN=false runs for real' do
      ENV['DRY_RUN'] = 'false'
      expect { invoke }.to have_enqueued_job(job_class).with(campaign.id)
    end
  end

  describe 're-firing through reconcile does not double-send (the delivery claim row protects)' do
    let(:first_user) { intervention.predefined_users.first }
    let(:second_user) { intervention.predefined_users.second }
    let(:campaign) { stranded_campaign(intervention: intervention, kind: 'invitation', status: 'scheduled') }

    before do
      create_us_phone!(first_user, 0)
      create_us_phone!(second_user, 1)
      stub_successful_sms_delivery
      create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: first_user.predefined_user_parameter,
                                status: 'sent', sent_at: now - 4.hours)
    end

    it 'sends exactly one message — to the participant who has no claim row' do
      expect { reconcile_and_run_jobs }.to change(Message, :count).by(1)
    end

    it 'leaves the already-sent delivery untouched (no resend bookkeeping, still one row for that participant)' do
      reconcile_and_run_jobs
      deliveries = campaign.deliveries.where(predefined_user_parameter: first_user.predefined_user_parameter)
      expect(deliveries.count).to eq(1)
      expect(deliveries.first).to have_attributes(status: 'sent', resend_count: 0)
    end

    it 'does not send again when reconcile fires a second time after the stamps were lost' do
      reconcile_and_run_jobs
      PredefinedUserParameter.where(intervention_id: intervention.id).update_all(sms_invitation_sent_at: nil)
      campaign.update_columns(status: 'sending', updated_at: now - 3.hours)

      expect { reconcile_and_run_jobs }.not_to change(Message, :count)
      expect(campaign.deliveries.count).to eq(2)
    end
  end

  describe 'exactly four new messages, the participant already served is not messaged again' do
    let!(:intervention) { create(:intervention, :published, user: researcher) }
    let!(:participants) { Array.new(5) { |i| campaign_participant(intervention, index: i) } }
    let(:already_served) { participants.first }
    let(:campaign) do
      stranded_campaign(intervention: intervention, kind: 'invitation', status: 'sending', recipients_count: 5, accepted_count: 1)
    end

    before do
      stub_successful_sms_delivery
      create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: already_served, status: 'sent', sent_at: now - 2.hours)
    end

    it 'sends to exactly the four recipients who were not reached and not again to the one who was' do
      expect { reconcile_and_run_jobs }.to change(Message, :count).by(4)

      deliveries = PredefinedParticipants::SmsDelivery.where(campaign_id: campaign.id)
      expect(deliveries.count).to eq(5)
      expect(deliveries.where(status: 'sent').count).to eq(5)
      expect(deliveries.find_by(predefined_user_parameter_id: already_served.id).message_id).to be_nil
    end
  end
end
