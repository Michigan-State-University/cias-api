class AddExternalNameToClinicLocation < ActiveRecord::Migration[6.1]
  def change
    add_column :clinic_locations, :external_name, :string
  end
end
