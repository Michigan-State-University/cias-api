# frozen_string_literal: true

class AddSmsPlansCountToSessions < ActiveRecord::Migration[6.0]
  def change
    add_column :sessions, :sms_plans_count, :integer, default: 0, null: false
  end
end
