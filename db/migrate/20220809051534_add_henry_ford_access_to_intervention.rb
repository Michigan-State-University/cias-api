class AddHenryFordAccessToIntervention < ActiveRecord::Migration[6.1]
  def change
    add_column :interventions, :hfhs_access, :boolean, default: false
  end
end
