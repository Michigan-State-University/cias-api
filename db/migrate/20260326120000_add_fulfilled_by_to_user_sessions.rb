# frozen_string_literal: true

class AddFulfilledByToUserSessions < ActiveRecord::Migration[7.2]
  def change
    add_column :user_sessions, :fulfilled_by_id, :uuid, null: true
    add_index :user_sessions, :fulfilled_by_id
    add_foreign_key :user_sessions, :users, column: :fulfilled_by_id
  end
end
