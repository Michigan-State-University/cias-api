class AddStarredFlagToIntervention < ActiveRecord::Migration[6.1]
  def change
    add_column(:interventions, :starred, :boolean, null: false, default: false)
  end
end
