# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SmsInboundReceipt, type: :model do
  describe '.purge_stale' do
    around { |example| freeze_time { example.run } }

    it 'deletes receipts older than the retention window and keeps recent ones' do
      stale = described_class.create!(message_sid: 'SM_old', created_at: described_class::RETENTION.ago - 1.day)
      fresh = described_class.create!(message_sid: 'SM_new', created_at: 1.day.ago)

      described_class.purge_stale

      expect(described_class.exists?(stale.id)).to be(false)
      expect(described_class.exists?(fresh.id)).to be(true)
    end

    it 'keeps a receipt exactly at the retention boundary' do
      boundary = described_class.create!(message_sid: 'SM_boundary', created_at: described_class::RETENTION.ago)

      described_class.purge_stale

      expect(described_class.exists?(boundary.id)).to be(true)
    end
  end
end
