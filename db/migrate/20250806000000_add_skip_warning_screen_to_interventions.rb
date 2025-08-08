# frozen_string_literal: true

class AddSkipWarningScreenToInterventions < ActiveRecord::Migration[6.1]
  def change
    add_column :interventions, :skip_warning_screen, :boolean, default: false, null: false
  end
end
