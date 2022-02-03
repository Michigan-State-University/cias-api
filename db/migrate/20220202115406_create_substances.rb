# frozen_string_literal: true

class CreateSubstances < ActiveRecord::Migration[6.1]
  def change
    create_table :substances do |t|
      t.string :name, null: false, default: ''
      t.string :unit, null: false, default: ''
      t.references :user_session, null: false, foreign_key: true, type: :uuid
      t.jsonb :body
      t.timestamps
    end
  end
end
