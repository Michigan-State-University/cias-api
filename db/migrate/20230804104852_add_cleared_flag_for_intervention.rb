class AddClearedFlagForIntervention < ActiveRecord::Migration[6.1]
  def change
    add_column(:interventions, :cleared, :boolean, null: false, default: false)
  end
end
