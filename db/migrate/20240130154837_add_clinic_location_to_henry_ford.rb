class AddClinicLocationToHenryFord < ActiveRecord::Migration[6.1]
  def change
    add_new_clinic_location_to_henry_ford!
  end

  class AuxiliaryClinicLocation < ActiveRecord::Base
    self.table_name = 'clinic_locations'
  end

  def add_new_clinic_location_to_henry_ford!
    [
      {
        department: '',
        name: 'SBH LINCOLN PARK MIDDLE SCHOOL HEALTH CTR',
        external_id: '1011430001',
        external_name: 'Henry Ford School Based Health Center -  Lincoln Park Middle School',
      },
      {
        department: '',
        name: 'SBH MUMFORD HEALTH CTR',
        external_id: '1010010181',
        external_name: 'Henry Ford School Based Health Center -  Samuel C. Mumford High School',
      },
      {
        department: '',
        name: 'SBH EARHART HEALTH CTR',
        external_id: '1010010222',
        external_name: 'Henry Ford School Based Health Center -  Amelia Earhart Elementary / Middle School',
      }
    ].each do |clinic_location_params|
      AuxiliaryClinicLocation.find_or_create_by!(clinic_location_params)
    end
  end
end
