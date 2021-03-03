# frozen_string_literal: true

class CreateSmsPlans < ActiveRecord::Migration[6.0]
  def change
    create_table :sms_plans, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :session_id, index: true, foreign_key: true
      t.string :name, null: false
      t.string :schedule, null: false
      t.integer :schedule_payload
      t.string :frequency, default: 'once', null: false
      t.datetime :end_at
      t.string :formula
      t.text :no_formula_text
      t.boolean :is_used_formula, default: false, null: false

      t.timestamps
    end
  end
end
