# frozen_string_literal: true

class AddEstimatedTimeToSessions < ActiveRecord::Migration[6.0]
  def change
    add_column :sessions, :estimated_time, :integer, default: 0
  end
end
