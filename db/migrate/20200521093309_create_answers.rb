# frozen_string_literal: true

class CreateAnswers < ActiveRecord::Migration[6.0]
  def change
    create_table :answers, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :type
      t.uuid :question_id, null: false
      t.uuid :user_id
      t.jsonb :body

      t.timestamps
    end

    add_index :answers, :type
    add_index :answers, :question_id
    add_index :answers, :user_id
    add_index :answers, %i[type question_id user_id], unique: true

    add_foreign_key :answers, :users
    add_foreign_key :answers, :questions
  end
end
