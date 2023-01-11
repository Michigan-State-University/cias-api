# frozen_string_literal: true

class AddDefaultValueToNumberOfAttemptsColumn < ActiveRecord::Migration[6.1]
  def change
    change_column :user_sessions, :number_of_attempts, :integer, default: 1
  end
end
