# frozen_string_literal: true

class UpdateClinicLocationNamesFromHenryFord < ActiveRecord::Migration[6.1]
  def change
    add_column :clinic_locations, :epic_identifier, :text, default: ''
    add_column :clinic_locations, :auxiliary_epic_identifier, :text, default: ''
    update_henry_ford_clinic_locations!
  end

  class AuxiliaryClinicLocation < ApplicationRecord
    self.table_name = 'clinic_locations'
  end

  def update_henry_ford_clinic_locations!
    [
      {
        department: '',
        name: 'bloom twp pediatrics',
        external_id: '1011220001',
        external_name: 'Henry Ford Pediatrics - Bloomfield Twp',
        epic_identifier: 'e.hJveFXv2ZcfoeLG1TynHqE3TMauseacliplt-.56Qo3',
        auxiliary_epic_identifier: '',
      },
      {
        department: '',
        name: 'beck rd pediatrics',
        external_id: '1010300007',
        external_name: 'Henry Ford Pediatrics - Beck Rd',
        epic_identifier: 'exgw90yOnaHBd.pUwyKrwU6MSTjuHj4H8t1xh8s2FrR03',
        auxiliary_epic_identifier: '',
      },
      {
        department: '',
        name: 'nco pediatrics',
        external_id: '1010270012',
        external_name: 'Henry Ford Pediatrics - New Center One',
        epic_identifier: 'eADkgg0Rxh4fFV-SZ.uhefte3QnvY1j.CZHi6VBdso903',
        auxiliary_epic_identifier: '',
      },
      {
        department: '',
        name: 'SBH LINCOLN PARK MIDDLE SCHOOL HEALTH CTR',
        external_id: '1011430001',
        external_name: 'Henry Ford School Based Health - Lincoln Park Middle School',
        epic_identifier: 'e0XlinYuE77F8qaXJLlZosxdExRoD56S6PMb7KaH87q03',
        auxiliary_epic_identifier: '',
      },
      {
        department: '',
        name: 'SBH MUMFORD HEALTH CTR',
        external_id: '1010010181',
        external_name: 'Henry Ford School Based Health - Mumford High School',
        epic_identifier: 'eUahgOHZfbQrK16kZoUBH31RzlrjPlQhn978-4wIIrJY3',
        auxiliary_epic_identifier: '',
      },
    ].each do |clinic_location_params|
      clinic_location = AuxiliaryClinicLocation.find_by(name: clinic_location_params[:name])
      if clinic_location.present?
        clinic_location.update!(clinic_location_params)
      else
        AuxiliaryClinicLocation.create!(clinic_location_params)
      end
    end
  end
end
