# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::PredefinedParticipants::SmsCampaigns::PayloadValidator do
  subject(:validate) { described_class.call(attributes) }

  let(:attributes) do
    instance_double(
      V1::PredefinedParticipants::SmsCampaigns::CampaignAttributes,
      kind: kind, body: 'Hello', links: [], reminder: reminder,
      reminder_body: 'Reminder', reminder_links: [], days_after: days_after
    )
  end
  let(:kind) { 'invitation' }
  let(:reminder) { nil }
  let(:days_after) { 5 }

  before do
    allow(V1::PredefinedParticipants::SmsCampaigns::TextCodes).to receive(:call).and_return([])
  end

  def codes_from(error)
    error.additional_information[:errors].map { |entry| entry[:code] }
  end

  context 'with a valid invitation payload' do
    it 'does not raise' do
      expect { validate }.not_to raise_error
    end
  end

  context 'when the kind is not creatable' do
    let(:kind) { 'scheduled_reminder' }

    it 'raises ComplexException with the INVALID_KIND code' do
      expect { validate }.to raise_error(ComplexException) do |error|
        expect(codes_from(error)).to include('INVALID_KIND')
      end
    end
  end

  context 'when a reminder is present but the kind is not an invitation' do
    let(:kind) { 'manual_reminder' }
    let(:reminder) { { body: 'Reminder' } }

    it 'raises ComplexException with the SCHEDULED_REMINDER_NOT_ALLOWED code' do
      expect { validate }.to raise_error(ComplexException) do |error|
        expect(codes_from(error)).to include('SCHEDULED_REMINDER_NOT_ALLOWED')
      end
    end
  end

  context 'when days_after is outside the allowed range' do
    let(:reminder) { { body: 'Reminder' } }
    let(:days_after) { 0 }

    before { allow(Settings.sms_campaigns).to receive(:max_reminder_days_after).and_return(60) }

    it 'raises ComplexException with the INVALID_DAYS_AFTER code' do
      expect { validate }.to raise_error(ComplexException) do |error|
        expect(codes_from(error)).to include('INVALID_DAYS_AFTER')
      end
    end
  end

  context 'when the reminder text has validation codes' do
    let(:reminder) { { body: 'Reminder' } }

    before do
      allow(V1::PredefinedParticipants::SmsCampaigns::TextCodes)
        .to receive(:call).with('Reminder', []).and_return(['BODY_BLANK'])
    end

    it 'prefixes the reminder codes with SCHEDULED_REMINDER_' do
      expect { validate }.to raise_error(ComplexException) do |error|
        expect(codes_from(error)).to include('SCHEDULED_REMINDER_BODY_BLANK')
      end
    end
  end
end
