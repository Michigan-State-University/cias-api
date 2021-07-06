class AddFromDeletedOrganizationToIntervention < ActiveRecord::Migration[6.0]
  def change
    add_column :interventions, :from_deleted_organization, :boolean, default: false, null: false
  end
end
