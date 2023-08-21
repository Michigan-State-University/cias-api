class AddThreeStateFlagsToInterventions < ActiveRecord::Migration[6.1]
  def change
    remove_column(:interventions, :reports_deleted)
    remove_column(:interventions, :data_cleared)
    add_column(:interventions, :sensitive_data_state, :string, null: false, default: 'collected' )
    add_column(:interventions, :clear_sensitive_data_scheduled_at, :datetime )
  end
end
