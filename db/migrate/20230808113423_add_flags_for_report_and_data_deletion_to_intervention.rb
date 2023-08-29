class AddFlagsForReportAndDataDeletionToIntervention < ActiveRecord::Migration[6.1]
  def change
    add_column(:interventions, :reports_deleted, :boolean, null: false, default: false)
    add_column(:interventions, :data_cleared, :boolean, null: false, default: false)
  end
end
