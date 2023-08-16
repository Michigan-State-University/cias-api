class AddExternalIdToClinicLocations < ActiveRecord::Migration[6.1]
  def change
    add_column(:clinic_locations, :external_id, :string)
    add_index(:clinic_locations, :external_id, unique: true)
    Rake::Task['one_time_use:assign_external_id_to_clinic_location'].invoke
  end
end
