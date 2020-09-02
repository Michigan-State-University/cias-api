# frozen_string_literal: true

class CreateUserProblems < ActiveRecord::Migration[6.0]
  def change
    create_table :user_problems, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :user_id, null: false
      t.uuid :problem_id, null: false

      t.timestamps
    end

    add_index :user_problems, :user_id
    add_index :user_problems, :problem_id
    add_index :user_problems, %i[user_id problem_id], unique: true

    add_foreign_key :user_problems, :users
    add_foreign_key :user_problems, :problems
  end
end
