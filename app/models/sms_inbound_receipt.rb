# frozen_string_literal: true

class SmsInboundReceipt < ApplicationRecord
  RETENTION = 30.days

  validates :message_sid, presence: true

  def self.purge_stale(now: Time.current)
    where(created_at: ...(now - RETENTION)).delete_all
  end

  def self.claim(message_sid)
    # rubocop:disable Rails/SkipsModelValidations
    insert({ message_sid: message_sid }, unique_by: :message_sid).rows.dig(0, 0)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
