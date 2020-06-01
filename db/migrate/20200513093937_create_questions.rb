# frozen_string_literal: true

class CreateQuestions < ActiveRecord::Migration[6.0]
  def change
    create_table :questions, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :type, null: false
      t.uuid :intervention_id, null: false
      t.integer :order
      t.string :title, null: false
      t.string :subtitle
      t.string :video
      t.string :formula
      t.jsonb :body, default: { data: [] }

      t.timestamps
    end

    add_index :questions, :type
    add_index :questions, :intervention_id
    add_index :questions, :title
    add_index :questions, %i[type title], using: :gin
    add_index :questions, %i[type intervention_id title], using: :gin

    add_foreign_key :questions, :interventions
  end
end
