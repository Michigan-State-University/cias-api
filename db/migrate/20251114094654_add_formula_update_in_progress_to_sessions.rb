# frozen_string_literal: true

class AddFormulaUpdateInProgressToSessions < ActiveRecord::Migration[7.2]
  def change
    add_column :sessions, :formula_update_in_progress, :boolean, default: false, null: false
  end
end
