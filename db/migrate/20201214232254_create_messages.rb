# frozen_string_literal: true

class CreateMessages < ActiveRecord::Migration[6.0]
  def change
    create_table :messages do |t|
      t.string :phone, null: false
      t.text :body, null: false
      t.string :status, null: false, default: 'new'
      t.datetime :schedule_at

      t.timestamps null: false
    end
  end
end
