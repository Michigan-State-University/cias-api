# frozen_string_literal: true

class CreateInterventions < ActiveRecord::Migration[6.0]
  def change
    create_table :interventions, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :type, null: false
      t.uuid :user_id, null: false
      t.uuid :problem_id
      t.jsonb :settings
      t.boolean :allow_guests, null: false, default: false
      t.string :status
      t.string :name, null: false
      t.string :slug
      t.jsonb :body, default: { data: [] }

      t.timestamps
    end

    add_index :interventions, :type
    add_index :interventions, :user_id
    add_index :interventions, :problem_id
    add_index :interventions, :allow_guests
    add_index :interventions, :status
    add_index :interventions, %i[allow_guests status], using: :gin
    add_index :interventions, :name
    add_index :interventions, :slug, unique: true
    add_index :interventions, %i[type name], using: :gin
    add_index :interventions, %i[type user_id name], using: :gin

    add_foreign_key :interventions, :users
  end
end
