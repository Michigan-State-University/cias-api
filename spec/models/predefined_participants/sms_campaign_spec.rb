# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PredefinedParticipants::SmsCampaign', type: :model do
  let(:model) { 'PredefinedParticipants::SmsCampaign'.constantize }
  let(:intervention) { create(:intervention, :published) }
  let(:campaign) { create(:pdp_sms_campaign, intervention: intervention) }

  describe 'table and associations' do
    it 'uses the namespaced table name' do
      expect(model.table_name).to eq('predefined_participants_sms_campaigns')
    end

    it 'has many sms_links through campaign_id, destroyed with the campaign' do
      expect(model.new).to have_many(:sms_links)
        .class_name('SmsLink').with_foreign_key(:campaign_id).inverse_of(:campaign).dependent(:destroy)
    end

    it 'has many deliveries through campaign_id, destroyed with the campaign' do
      expect(model.new).to have_many(:deliveries)
        .class_name('PredefinedParticipants::SmsDelivery').with_foreign_key(:campaign_id)
        .inverse_of(:campaign).dependent(:destroy)
    end

    it 'has one scheduled_reminder through parent_campaign_id' do
      expect(model.new).to have_one(:scheduled_reminder)
        .class_name('PredefinedParticipants::SmsCampaign').with_foreign_key(:parent_campaign_id)
        .inverse_of(:parent_campaign)
    end

    it 'belongs to an optional parent_campaign' do
      expect(model.new).to belong_to(:parent_campaign)
        .class_name('PredefinedParticipants::SmsCampaign').optional
    end

    it 'requires an intervention' do
      record = build(:pdp_sms_campaign, intervention: nil)
      expect(record).not_to be_valid
      expect(record.errors[:intervention]).to be_present
    end

    it 'is valid without a parent campaign' do
      expect(build(:pdp_sms_campaign, parent_campaign: nil)).to be_valid
    end

    it 'requires a body' do
      expect(model.new).to validate_presence_of(:body)
    end

    it 'rejects a blank body' do
      record = build(:pdp_sms_campaign, body: '')
      expect(record).not_to be_valid
      expect(record.errors[:body]).to be_present
    end

    it 'exposes the child reminder through scheduled_reminder' do
      campaign.update!(status: 'sent')
      child = create(:pdp_sms_campaign, intervention: intervention, kind: 'scheduled_reminder',
                                        parent_campaign: campaign, days_after: 3)
      expect(campaign.reload.scheduled_reminder).to eq(child)
      expect(child.parent_campaign).to eq(campaign)
    end

    it 'destroys its links and deliveries together with the campaign' do
      link = create(:pdp_campaign_sms_link, campaign: campaign)
      delivery = create(:pdp_sms_delivery, campaign: campaign,
                                           predefined_user_parameter: create(:predefined_user_parameter, intervention: intervention))
      campaign.destroy!
      expect(SmsLink.exists?(link.id)).to be(false)
      expect(PredefinedParticipants::SmsDelivery.exists?(delivery.id)).to be(false)
    end
  end

  describe 'body is excluded from audit' do
    it 'keeps the body out of audited_changes after create and update' do
      campaign.update!(body: 'CIAS_TDD_CANARY_BODY changed', status: 'sending')
      changes = campaign.audits.map(&:audited_changes)
      expect(campaign.audits.size).to be >= 2
      expect(changes.to_json).not_to include('CIAS_TDD_CANARY_BODY')
      expect(changes.flat_map(&:keys)).not_to include('body')
    end

    it 'still audits the other attributes' do
      campaign.update!(status: 'sending')
      expect(campaign.audits.last.audited_changes).to include('status')
    end
  end

  describe 'status subset constants' do
    it 'defines OPEN_STATUSES as scheduled and sending, a frozen subset of the statuses' do
      expect(model::OPEN_STATUSES).to eq(%w[scheduled sending])
      expect(model::OPEN_STATUSES).to be_frozen
      expect(model.statuses.keys).to include(*model::OPEN_STATUSES)
    end

    it 'defines NOT_SENDING_STATUSES as cancelled and skipped, a frozen subset of the statuses' do
      expect(model::NOT_SENDING_STATUSES).to eq(%w[cancelled skipped])
      expect(model::NOT_SENDING_STATUSES).to be_frozen
      expect(model.statuses.keys).to include(*model::NOT_SENDING_STATUSES)
    end
  end

  describe '#reminder_scheduled_at' do
    let(:from) { Time.zone.parse('2026-10-24 12:00:00') }

    it 'offsets from by days_after days, computed in the author timezone' do
      author = create(:user, time_zone: 'Pacific/Honolulu')
      campaign = build(:pdp_sms_campaign, author: author)
      expect(campaign.reminder_scheduled_at(from, 3)).to eq(from.in_time_zone('Pacific/Honolulu') + 3.days)
    end

    it 'adds calendar days in the author timezone, so a DST fall-back preserves the wall-clock time' do
      author = create(:user, time_zone: 'Europe/Warsaw')
      campaign = build(:pdp_sms_campaign, author: author)
      local_from = Time.find_zone('Europe/Warsaw').parse('2026-10-24 12:00:00')
      result = campaign.reminder_scheduled_at(local_from, 3)
      expect(result.in_time_zone('Europe/Warsaw').strftime('%Y-%m-%d %H:%M')).to eq('2026-10-27 12:00')
      expect(result - local_from).to eq(3.days + 1.hour)
    end

    it 'falls back to Time.zone when the author is nil' do
      campaign = build(:pdp_sms_campaign, author: nil)
      expect(campaign.reminder_scheduled_at(from, 2)).to eq(from.in_time_zone(Time.zone) + 2.days)
    end
  end

  describe '#transition_to' do
    it 'transitions a scheduled campaign and returns the row count' do
      expect(campaign.transition_to('sending')).to eq(1)
      expect(campaign.reload.status).to eq('sending')
    end

    it 'transitions a sending campaign, since sending is an open status' do
      campaign.update!(status: 'sending')
      expect(campaign.transition_to('skipped')).to eq(1)
      expect(campaign.reload.status).to eq('skipped')
    end

    %w[sent failed cancelled].each do |terminal|
      it "does not transition a #{terminal} campaign and returns zero" do
        campaign.update!(status: terminal)
        expect(campaign.transition_to('sending')).to eq(0)
        expect(campaign.reload.status).to eq(terminal)
      end
    end
  end

  describe '#record_recipients_count' do
    it 'sets recipients_count when it is nil and returns the row count' do
      expect(campaign.recipients_count).to be_nil
      expect(campaign.record_recipients_count(5)).to eq(1)
      expect(campaign.reload.recipients_count).to eq(5)
    end

    it 'is a no-op that returns zero when recipients_count is already set' do
      campaign.update!(recipients_count: 7)
      expect(campaign.record_recipients_count(3)).to eq(0)
      expect(campaign.reload.recipients_count).to eq(7)
    end
  end

  describe '#close!' do
    before { travel_to(Time.zone.parse('2026-11-11 12:00:00')) }

    it 'closes a sending campaign with accepted messages as sent, stamps sent_at and returns the count' do
      campaign.update!(status: 'sending', accepted_count: 2)
      expect(campaign.close!).to eq(1)
      expect(campaign.reload.status).to eq('sent')
      expect(campaign.sent_at).to be_within(1.second).of(Time.current)
    end

    it 'closes a sending campaign that accepted nobody as failed and stamps sent_at' do
      campaign.update!(status: 'sending', accepted_count: 0)
      expect(campaign.close!).to eq(1)
      expect(campaign.reload.status).to eq('failed')
      expect(campaign.sent_at).to be_within(1.second).of(Time.current)
    end

    it 'does not close a campaign that is not sending and returns zero' do
      campaign.update!(status: 'scheduled')
      expect(campaign.close!).to eq(0)
      expect(campaign.reload.status).to eq('scheduled')
    end

    it 'anchors the scheduled reminder to the send time when the campaign closes as sent' do
      campaign.update!(status: 'sending', accepted_count: 1)
      reminder = create(:pdp_sms_campaign, intervention: intervention, kind: 'scheduled_reminder',
                                           parent_campaign: campaign, days_after: 3, status: 'scheduled')
      campaign.close!
      expect(campaign.reload.status).to eq('sent')
      expect(reminder.reload.scheduled_at).to be_within(1.second).of(3.days.from_now)
    end

    it 'does not anchor the reminder when the campaign closes as failed' do
      campaign.update!(status: 'sending', accepted_count: 0)
      reminder = create(:pdp_sms_campaign, intervention: intervention, kind: 'scheduled_reminder',
                                           parent_campaign: campaign, days_after: 3, status: 'scheduled')
      planned = reminder.scheduled_at
      campaign.close!
      expect(campaign.reload.status).to eq('failed')
      expect(reminder.reload.scheduled_at).to be_within(1.second).of(planned)
    end
  end

  describe 'no PaperTrail' do
    it 'does not declare has_paper_trail' do
      expect(model.reflect_on_association(:versions)).to be_nil
      expect(model).not_to respond_to(:paper_trail_options)
    end

    it 'writes no PaperTrail versions on create and update' do
      campaign.update!(status: 'sending', body: 'CIAS_TDD_CANARY_BODY changed')
      expect(PaperTrail::Version.where(item_type: model.name)).to be_empty
    end
  end
end
