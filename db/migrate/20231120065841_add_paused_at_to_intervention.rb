class AddPausedAtToIntervention < ActiveRecord::Migration[6.1]
  def change
    add_column :interventions, :paused_at, :datetime
  end
end
