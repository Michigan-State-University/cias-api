# frozen_string_literal: true

class UpdateClinicLocationsFromHenryFord < ActiveRecord::Migration[6.1]
  def change
    update_henry_ford_clinic_locations!
  end

  class AuxiliaryClinicLocation < ApplicationRecord
    self.table_name = 'clinic_locations'
  end

  def update_henry_ford_clinic_locations!
    [
      {
        department: '',
        name: 'farm rd pediatrics',
        external_id: '1010190005',
        external_name: 'Henry Ford Pediatrics - Farmington Rd',
        epic_identifier: 'eRaDdadOgXGAytElLNpWnvupLeBtFGhOB34mj0hFJa2s3',
        auxiliary_epic_identifier: '',
      },
      {
        department: '',
        name: 'st hgts pediatrics',
        external_id: '1010320012',
        external_name: 'Henry Ford Pediatrics - Sterling Heights',
        epic_identifier: 'eKdX81lr4SVUXMipYC--I.3wrqCT.AtAHxC7SJEKYUuw3',
        auxiliary_epic_identifier: '',
      },
      {
        department: '',
        name: 'commerce family medicine',
        external_id: '1010130002',
        external_name: 'Henry Ford Family Medicine - Commerce',
        epic_identifier: 'es71cC3GTyfz6VDt8bYZ2uC16Wv03z5jaXjFf6tetNtw3',
        auxiliary_epic_identifier: '',
      },
      {
        department: '',
        name: 'hamtramck pediatrics',
        external_id: '1010210018',
        external_name: 'Henry Ford Pediatrics - Hamtramck',
        epic_identifier: 'e3LdnQRVGB13qpQdZgMlV8tU66Ke8J-hHQWHis9RDFs03',
        auxiliary_epic_identifier: '',
      },
      {
        department: '',
        name: 'SBH EARHART HEALTH CTR',
        external_id: '1010010222',
        external_name: 'Henry Ford School Based Health - Earhart Elementary-Middle School',
        epic_identifier: 'eeI.n993HZ19rWEiPJEu.zXBwNFefn.4gsLV6oTtj0Jo3',
        auxiliary_epic_identifier: '',
      },
      {
        department: '',
        name: 'livonia pediatrics',
        external_id: '1010240009',
        external_name: 'Henry Ford Pediatrics - Livonia',
        epic_identifier: 'eFhHZqH5CtO8yDYP5O7.TjuMRZ2n9y87.vM.kPvbEM3M3',
        auxiliary_epic_identifier: '',
      },
      {
        department: '',
        name: 'bloom twp family medicine',
        external_id: '1011220023',
        external_name: 'Henry Ford Family Medicine - Bloomfield Twp',
        epic_identifier: 'eF9ok8vriLWc8dDel4zmnD3HpnXfvtcWXnSqQDoYvbqY3',
        auxiliary_epic_identifier: '',
      },
      {
        department: '',
        name: 'roy oak pediatrics',
        external_id: '1011410027',
        external_name: 'Henry Ford Pediatrics - Royal Oak',
        epic_identifier: 'eu-Dcnz-kWm8.SFtCPcHRHYnHCF8gUxKrJ6YZV35S-rk3',
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
