class AddCatMhFieldsToInterventions < ActiveRecord::Migration[6.0]
  def change
    add_column :interventions, :cat_mh_application_id, :string
    add_column :interventions, :cat_mh_organization_id, :string
    add_column :interventions, :cat_mh_pool, :integer
  end
end
