class AddMissingCatMhFieldsToIntervention < ActiveRecord::Migration[6.0]
  def change
    add_column :interventions, :is_access_revoked, :boolean, default: false
    add_column :interventions, :license_type, :string, default: 'limited'
  end
end
