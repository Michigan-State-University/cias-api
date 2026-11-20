# frozen_string_literal: true

class CreateSmsInboundReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :sms_inbound_receipts, id: :uuid, default: 'uuid_generate_v4()' do |t|
      t.string :message_sid, null: false, index: { unique: true }
      t.datetime :created_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }, index: true
    end
  end
end
