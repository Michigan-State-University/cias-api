# frozen_string_literal: true

class RenameProblemToIntervention < ActiveRecord::Migration[6.0]
  def change
    rename_table :problems, :interventions
    rename_column :sessions, :problem_id, :intervention_id
  end
end
