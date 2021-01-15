# frozen_string_literal: true

class CreatePhones < ActiveRecord::Migration[6.0]
  def change
    create_table :phones do |t|
      t.uuid :user_id, index: true, foreign_key: true
      t.string :iso, null: false
      t.string :prefix, null: false
      t.string :number, null: false
      t.string :confirmation_code
      t.boolean :confirmed, null: false, default: false
      t.datetime :confirmed_at

      t.timestamps null: false
    end
  end
end
