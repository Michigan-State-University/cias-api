class AddClinicLocationToHenryFord < ActiveRecord::Migration[6.1]
  def change
    add_new_clinic_location_to_henry_ford!
  end

  class AuxiliaryClinicLocation < ApplicationRecord
    self.table_name = 'clinic_locations'
  end

  def add_new_clinic_location_to_henry_ford!
    AuxiliaryClinicLocation.find_or_create_by!(
      department: '',
      name: 'HAMTRAMCK PEDIATRICS',
      external_id: '1010210018',
      external_name: 'HAMTRAMCK PEDIATRICS',
    )
  end
end
