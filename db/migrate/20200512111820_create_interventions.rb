# frozen_string_literal: true

class CreateInterventions < ActiveRecord::Migration[6.0]
  def change
    create_table :interventions do |t|
      t.string :type, null: false
      t.belongs_to :user, null: false
      t.string :name, null: false
      t.jsonb :body

      t.timestamps
    end

    add_index :interventions, :type
    add_index :interventions, %i[type name], using: :gin

    add_foreign_key :interventions, :users
  end
end
