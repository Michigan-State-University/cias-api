class AddPartialIndexOnUserIntervention < ActiveRecord::Migration[6.1]
  def change
    add_index :user_interventions, [:intervention_id, :user_id], where: "(created_at > '2023-10-25 05:30:04'::timestamp)", unique: true
  end
end
