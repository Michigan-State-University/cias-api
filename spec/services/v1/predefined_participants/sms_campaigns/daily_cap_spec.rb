# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::PredefinedParticipants::SmsCampaigns::DailyCap do
  subject(:enforce) { described_class.enforce!(intervention, recipients_count) }

  let(:intervention) { create(:intervention, :published) }
  let(:recipients_count) { 5 }

  def stub_cap(value)
    allow(Settings.sms_campaigns).to receive(:daily_sms_cap).and_return(value)
  end

  def committed_campaign(on_intervention, recipients:, status: 'sent', scheduled_at: 1.hour.ago)
    create(:pdp_sms_campaign, intervention: on_intervention, status: status, recipients_count: recipients,
                              scheduled_at: scheduled_at)
  end

  context 'when the cap is blank' do
    before do
      stub_cap(nil)
      committed_campaign(intervention, recipients: 10_000)
    end

    it 'does not raise regardless of committed volume' do
      expect { enforce }.not_to raise_error
    end
  end

  context 'when committed volume plus recipients is within the cap' do
    before do
      stub_cap(50)
      committed_campaign(intervention, recipients: 5)
    end

    it 'does not raise' do
      expect { enforce }.not_to raise_error
    end
  end

  context 'when committed volume plus recipients exceeds the cap' do
    before do
      stub_cap(7)
      committed_campaign(intervention, recipients: 5)
    end

    it 'raises a ComplexException carrying the exceeded code and status' do
      expect { enforce }.to raise_error(ComplexException) do |error|
        expect(error.additional_information[:errors].first[:code]).to eq('DAILY_SMS_CAP_EXCEEDED')
        expect(error.status_code).to eq(:unprocessable_content)
      end
    end
  end

  context 'when committed campaigns are outside the 24h window' do
    before do
      stub_cap(7)
      committed_campaign(intervention, recipients: 5, scheduled_at: 25.hours.ago)
    end

    it 'does not count them towards the cap' do
      expect { enforce }.not_to raise_error
    end
  end

  context 'when committed campaigns are cancelled or skipped' do
    before do
      stub_cap(7)
      committed_campaign(intervention, recipients: 5, status: 'cancelled')
      committed_campaign(intervention, recipients: 5, status: 'skipped')
    end

    it 'does not count them towards the cap' do
      expect { enforce }.not_to raise_error
    end
  end

  context 'when the intervention belongs to an organization' do
    let(:organization) { create(:organization) }
    let(:sibling) { create(:intervention, :published) }

    before do
      stub_cap(7)
      intervention.update_columns(organization_id: organization.id)
      sibling.update_columns(organization_id: organization.id)
    end

    it 'counts committed campaigns of a sibling intervention in the same organization' do
      committed_campaign(sibling, recipients: 5)

      expect { enforce }.to raise_error(ComplexException)
    end
  end

  context 'when the intervention has no organization' do
    let(:sibling) { create(:intervention, :published) }

    before { stub_cap(7) }

    it 'does not count campaigns of another intervention' do
      committed_campaign(sibling, recipients: 5)

      expect { enforce }.not_to raise_error
    end

    it 'counts the intervention own committed campaigns' do
      committed_campaign(intervention, recipients: 5)

      expect { enforce }.to raise_error(ComplexException)
    end
  end
end
