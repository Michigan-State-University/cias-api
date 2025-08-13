class AddWarningScreenEnabledToInterventions < ActiveRecord::Migration[7.2]
  def change
    add_column :interventions, :warning_screen_enabled, :boolean, default: false, null: false
  end
end
