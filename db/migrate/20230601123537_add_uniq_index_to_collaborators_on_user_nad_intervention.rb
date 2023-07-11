class AddUniqIndexToCollaboratorsOnUserNadIntervention < ActiveRecord::Migration[6.1]
  def change
    add_index :collaborators, [:user_id, :intervention_id], unique: true
  end
end
