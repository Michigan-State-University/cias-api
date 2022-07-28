class AddQuickExitToIntervention < ActiveRecord::Migration[6.1]
  def change
    add_column :interventions, :quick_exit, :boolean, default: false
  end
end
