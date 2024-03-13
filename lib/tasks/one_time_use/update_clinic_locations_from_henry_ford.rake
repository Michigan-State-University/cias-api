# frozen_string_literal: true

namespace :one_time_use do
  task update_clinic_locations_for_henry_ford: :environment do
    update_henry_ford_clinic_locations!
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
      }
    ].each do |clinic_location_params|
      byebug
      clinic_location = ClinicLocation.find_by(name: clinic_location_params[:name])
      if clinic_location.present?
        clinic_location.update!(clinic_location_params)
      else
        ClinicLocation.create!(clinic_location_params)
      end
    end
  end
end
