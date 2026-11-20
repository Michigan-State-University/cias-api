# frozen_string_literal: true

class CreateSmsOptOuts < ActiveRecord::Migration[8.1]
  def change
    create_table :sms_opt_outs, id: :uuid, default: 'uuid_generate_v4()' do |t|
      t.references :user, type: :uuid, null: false, index: { unique: true },
                          foreign_key: { on_delete: :cascade }
      t.datetime :opted_out_at, null: false
    end
  end
end
