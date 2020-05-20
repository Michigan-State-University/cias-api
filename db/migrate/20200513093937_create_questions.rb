# frozen_string_literal: true

class CreateQuestions < ActiveRecord::Migration[6.0]
  def change
    create_table :questions do |t|
      t.string :type, null: false
      t.belongs_to :intervention, null: false
      t.references :previous
      t.string :title, null: false
      t.string :subtitle
      t.jsonb :body

      t.timestamps
    end

    add_index :questions, :type
    add_index :questions, :title
    add_index :questions, %i[type title], using: :gin

    add_foreign_key :questions, :interventions
  end
end
