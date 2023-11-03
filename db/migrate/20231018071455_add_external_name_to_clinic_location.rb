class AddExternalNameToClinicLocation < ActiveRecord::Migration[6.1]
  def change
    add_column :clinic_locations, :external_name, :string
    # Rake::Task['one_time_use:add_external_name_to_clinic_locations'].invoke
  end
end
