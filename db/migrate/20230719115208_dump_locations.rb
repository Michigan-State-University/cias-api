class DumpLocations < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['one_time_use:dump_clinic_locations'].invoke unless ClinicLocation.any?
  end
end
