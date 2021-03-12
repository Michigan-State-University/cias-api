# frozen_string_literal: true

class CreateSmsPlanVariants < ActiveRecord::Migration[6.0]
  def change
    create_table :sms_plan_variants, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :sms_plan_id, index: true, foreign_key: true
      t.string :formula_match
      t.text :content

      t.timestamps
    end
  end
end
