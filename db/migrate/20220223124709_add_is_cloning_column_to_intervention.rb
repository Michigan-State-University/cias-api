class AddIsCloningColumnToIntervention < ActiveRecord::Migration[6.1]
  def change
    add_column :interventions, :is_cloning, :boolean, default: false
  end
end
