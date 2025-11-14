# frozen_string_literal: true

class RemoveFormulaUpdateInProgressFromInterventions < ActiveRecord::Migration[7.2]
  def change
    remove_column :interventions, :formula_update_in_progress, :boolean, default: false, null: false
  end
end
