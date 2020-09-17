# frozen_string_literal: true

class CreateInterventions < ActiveRecord::Migration[6.0]
  def change
    create_table :interventions, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :problem_id, null: false
      t.jsonb :settings
      t.integer :position, null: false, default: 0
      t.string :name, null: false
      t.string :slug
      t.string :schedule
      t.integer :schedule_payload
      t.date :schedule_at
      t.jsonb :formula
      t.jsonb :body

      t.timestamps
    end

    add_index :interventions, :problem_id
    add_index :interventions, :name
    add_index :interventions, :slug, unique: true
    add_index :interventions, :schedule
    add_index :interventions, :schedule_at
    add_index :interventions, %i[problem_id name], using: :gin

    add_foreign_key :interventions, :problems
  end
end
