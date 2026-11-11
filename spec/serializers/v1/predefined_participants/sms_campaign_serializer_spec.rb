# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::PredefinedParticipants::SmsCampaignSerializer' do
  let(:intervention) { create(:intervention, :published) }
  let(:provisional_flag) { 'scheduled_at_provisional' }
  let(:sent_at) { Time.zone.parse('2026-10-29 12:30:00') }

  def serializer_class
    'V1::PredefinedParticipants::SmsCampaignSerializer'.constantize
  end

  def serialized(campaign)
    serializer_class.new(campaign).serializable_hash[:data]
  end

  def attributes_of(campaign)
    serialized(campaign)[:attributes].stringify_keys
  end

  def reminder_for(parent, **options)
    create(:pdp_sms_campaign, intervention: intervention, kind: 'scheduled_reminder', parent_campaign: parent, days_after: 3, **options)
  end

  describe 'fields' do
    let(:campaign) do
      create(:pdp_sms_campaign, intervention: intervention, status: 'sent', sent_at: sent_at,
                                recipients_count: 5, accepted_count: 4, failed_count: 1)
    end

    it 'exposes exactly kind, status, scheduled_at, sent_at, the three counters and the provisional flag' do
      expect(attributes_of(campaign).keys).to match_array(%w[kind status scheduled_at sent_at recipients_count accepted_count
                                                             failed_count scheduled_at_provisional])
    end

    it 'never exposes the body, the author or the intervention' do
      keys = attributes_of(campaign).keys
      expect(keys).not_to include('body', 'author_id', 'intervention_id', 'parent_campaign_id', 'days_after')
    end

    it 'returns the record id' do
      expect(serialized(campaign)[:id]).to eq(campaign.id)
    end

    it 'returns kind and status as the enum strings' do
      expect(attributes_of(campaign)).to include('kind' => 'invitation', 'status' => 'sent')
    end

    it 'returns the three stored counters' do
      expect(attributes_of(campaign)).to include('recipients_count' => 5, 'accepted_count' => 4, 'failed_count' => 1)
    end

    it 'returns scheduled_at and sent_at' do
      attributes = attributes_of(campaign)
      expect(attributes['scheduled_at']).to be_within(1.second).of(campaign.scheduled_at)
      expect(attributes['sent_at']).to be_within(1.second).of(sent_at)
    end

    it 'returns recipients_count and sent_at as nil for a campaign that has not run' do
      pending_campaign = create(:pdp_sms_campaign, intervention: intervention, status: 'scheduled')
      expect(attributes_of(pending_campaign)).to include('recipients_count' => nil, 'sent_at' => nil, 'accepted_count' => 0,
                                                         'failed_count' => 0)
    end

    it 'returns every one of the six statuses unchanged' do
      statuses = %w[scheduled sending sent failed cancelled skipped]
      returned = statuses.map { |status| attributes_of(create(:pdp_sms_campaign, kind: 'manual_reminder', status: status))['status'] }
      expect(returned).to eq(statuses)
    end

    it 'serializes a collection' do
      campaigns = [create(:pdp_sms_campaign, intervention: intervention, status: 'sent'),
                   create(:pdp_sms_campaign, intervention: intervention, kind: 'manual_reminder', status: 'sent')]
      expect(serializer_class.new(campaigns).serializable_hash[:data].pluck(:id)).to match_array(campaigns.map(&:id))
    end
  end

  describe 'provisional flag of scheduled_at' do
    %w[scheduled sending].each do |parent_status|
      it "is true for a scheduled reminder whose parent is #{parent_status}" do
        parent = create(:pdp_sms_campaign, intervention: intervention, status: parent_status)
        expect(attributes_of(reminder_for(parent))[provisional_flag]).to be(true)
      end
    end

    %w[sent failed cancelled skipped].each do |parent_status|
      it "is false for a scheduled reminder whose parent is #{parent_status}" do
        parent = create(:pdp_sms_campaign, intervention: intervention, status: parent_status)
        expect(attributes_of(reminder_for(parent))[provisional_flag]).to be(false)
      end
    end

    it 'turns from true to false once the parent closes' do
      parent = create(:pdp_sms_campaign, intervention: intervention, status: 'sending')
      reminder = reminder_for(parent)
      expect(attributes_of(reminder)[provisional_flag]).to be(true)
      parent.update!(status: 'sent', sent_at: sent_at)
      expect(attributes_of(reminder.reload)[provisional_flag]).to be(false)
    end

    it 'is false for an immediate invitation even while it is scheduled' do
      campaign = create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'scheduled')
      expect(attributes_of(campaign)[provisional_flag]).to be(false)
    end

    it 'is false for an immediate manual reminder even while it is sending' do
      campaign = create(:pdp_sms_campaign, intervention: intervention, kind: 'manual_reminder', status: 'sending')
      expect(attributes_of(campaign)[provisional_flag]).to be(false)
    end

    it 'is false for a finished scheduled reminder whose parent is sent' do
      parent = create(:pdp_sms_campaign, intervention: intervention, status: 'sent')
      reminder = reminder_for(parent, status: 'sent', sent_at: sent_at)
      expect(attributes_of(reminder)[provisional_flag]).to be(false)
    end

    it 'is a strict boolean, never nil' do
      parent = create(:pdp_sms_campaign, intervention: intervention, status: 'sent')
      values = [attributes_of(parent), attributes_of(reminder_for(parent))].pluck(provisional_flag)
      expect(values).to all(satisfy { |value| [true, false].include?(value) })
    end
  end
end
