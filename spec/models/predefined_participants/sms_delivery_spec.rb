# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PredefinedParticipants::SmsDelivery', type: :model do
  let(:model) { 'PredefinedParticipants::SmsDelivery'.constantize }
  let(:intervention) { create(:intervention, :published) }
  let(:campaign) { create(:pdp_sms_campaign, intervention: intervention) }
  let(:participant) { create(:predefined_user_parameter, intervention: intervention) }
  let(:delivery) { create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: participant) }

  describe 'table and associations' do
    it 'uses the namespaced table name' do
      expect(model.table_name).to eq('predefined_participants_sms_deliveries')
    end

    it 'belongs to a campaign' do
      expect(model.new).to belong_to(:campaign).class_name('PredefinedParticipants::SmsCampaign')
    end

    it 'belongs to a predefined_user_parameter' do
      expect(model.new).to belong_to(:predefined_user_parameter)
    end

    it 'belongs to an optional message' do
      expect(model.new).to belong_to(:message).optional
    end

    it 'is invalid without a campaign' do
      record = build(:pdp_sms_delivery, campaign: nil)
      expect(record).not_to be_valid
      expect(record.errors[:campaign]).to be_present
    end

    it 'is invalid without a participant' do
      record = build(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: nil)
      expect(record).not_to be_valid
      expect(record.errors[:predefined_user_parameter]).to be_present
    end

    it 'is valid without a message' do
      expect(build(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: participant, message: nil)).to be_valid
    end

    it 'can reference the message that carried it' do
      message = create(:message, body: 'CIAS_TDD_CANARY_BODY')
      expect(delivery.tap { |d| d.update!(message: message) }.reload.message).to eq(message)
    end
  end

  describe 'body is excluded from audit' do
    it 'keeps the body out of audited_changes after create and update' do
      delivery.update!(body: 'CIAS_TDD_CANARY_BODY changed', status: 'sent')
      changes = delivery.audits.map(&:audited_changes)
      expect(delivery.audits.size).to be >= 2
      expect(changes.to_json).not_to include('CIAS_TDD_CANARY_BODY')
      expect(changes.flat_map(&:keys)).not_to include('body')
    end

    it 'still audits the other attributes' do
      delivery.update!(status: 'sent')
      expect(delivery.audits.last.audited_changes).to include('status')
    end
  end

  describe '.claim' do
    it 'inserts a pending delivery for the campaign and participant and returns it' do
      claimed = model.claim(campaign_id: campaign.id, predefined_user_parameter_id: participant.id, body: 'CIAS_TDD_CANARY_BODY')
      expect(claimed).to be_persisted
      expect(claimed).to have_attributes(campaign_id: campaign.id, predefined_user_parameter_id: participant.id,
                                         body: 'CIAS_TDD_CANARY_BODY', status: 'pending')
    end

    it 'returns nil when a row already exists for the same campaign and participant' do
      create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: participant)
      expect do
        result = model.claim(campaign_id: campaign.id, predefined_user_parameter_id: participant.id, body: 'another body')
        expect(result).to be_nil
      end.not_to change(model, :count)
    end
  end

  describe 'no PaperTrail' do
    it 'does not declare has_paper_trail' do
      expect(model.reflect_on_association(:versions)).to be_nil
      expect(model).not_to respond_to(:paper_trail_options)
    end

    it 'writes no PaperTrail versions on create and update' do
      delivery.update!(status: 'sent', body: 'CIAS_TDD_CANARY_BODY changed')
      expect(PaperTrail::Version.where(item_type: model.name)).to be_empty
    end
  end
end
