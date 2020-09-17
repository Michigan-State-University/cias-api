# frozen_string_literal: true

class CreateUserInterventions < ActiveRecord::Migration[6.0]
  def change
    create_table :user_interventions, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :user_id, null: false
      t.uuid :intervention_id, null: false
      t.datetime :submitted_at
      t.date :schedule_at

      t.timestamps
    end

    add_index :user_interventions, :user_id
    add_index :user_interventions, :intervention_id
    add_index :user_interventions, %i[user_id intervention_id], unique: true

    add_foreign_key :user_interventions, :users
    add_foreign_key :user_interventions, :interventions
  end
end
