# frozen_string_literal: true

class CreateAnswers < ActiveRecord::Migration[6.0]
  def change
    create_table :answers do |t|
      t.string :type
      t.belongs_to :question, null: false
      t.belongs_to :user
      t.jsonb :body, default: { data: [] }

      t.timestamps
    end

    add_index :answers, :type

    add_foreign_key :answers, :questions
  end
end
