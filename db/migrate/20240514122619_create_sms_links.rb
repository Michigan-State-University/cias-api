# frozen_string_literal: true

class CreateSmsLinks < ActiveRecord::Migration[6.1]
  def change
    create_table :sms_links, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :url, null: false
      t.integer :variable_number, null: false
      t.string :link_type, null: false, default: 'website'
      t.references :session, null: false, foreign_key: true, type: :uuid, index: true
      t.references :sms_plan, null: false, foreign_key: true, type: :uuid, index: true

      t.timestamps
    end
    add_index :sms_links, [:sms_plan_id, :variable_number], unique: true
  end
end
