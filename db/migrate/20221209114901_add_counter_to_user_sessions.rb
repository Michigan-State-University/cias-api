# frozen_string_literal: true

class AddCounterToUserSessions < ActiveRecord::Migration[6.1]
  def change
    add_column :user_sessions, :number_of_attempts, :integer
  end
end
