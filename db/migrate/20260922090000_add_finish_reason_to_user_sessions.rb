# frozen_string_literal: true

class AddFinishReasonToUserSessions < ActiveRecord::Migration[7.2]
  def change
    add_column :user_sessions, :finish_reason, :string, null: true
  end
end
