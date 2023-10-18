class AddPartialIndexOnUserIntervention < ActiveRecord::Migration[6.1]
  def change
    add_index :user_interventions, [:intervention_id, :user_id], where: "(created_at > '#{DateTime.now.utc.to_s}'::timestamp)", unique: true
  end
end
