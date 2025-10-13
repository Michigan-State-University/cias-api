# frozen_string_literal: true

class AddFormulaUpdateInProgressToInterventions < ActiveRecord::Migration[7.2]
  def change
    add_column :interventions, :formula_update_in_progress, :boolean, default: false, null: false
    add_index :interventions, :formula_update_in_progress
  end
end
