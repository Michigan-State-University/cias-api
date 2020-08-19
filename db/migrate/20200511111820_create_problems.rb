# frozen_string_literal: true

class CreateProblems < ActiveRecord::Migration[6.0]
  def change
    create_table :problems, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :name
      t.uuid :user_id, null: false
      t.boolean :allow_guests, null: false, default: false
      t.string :status

      t.timestamps
    end

    add_index :problems, :name
    add_index :problems, :user_id
    add_index :problems, :status
    add_index :problems, %i[name user_id], using: :gin

    add_foreign_key :problems, :users
  end
end
