# frozen_string_literal: true

namespace :one_time_use do
  desc ''
  task add_external_name_to_clinic_locations: :environment do
    begin
      ClinicLocation.reset_column_information
    rescue StandardError
      nil
    end

    locations = [
      {name: 'DETC INFECTIOUS DISEASE', id: 1010010049, external_name: 'DETC Infectious Disease', department: 'HFMC'},
      {name: 'FARM RD PEDIATRICS', id: 1010190005, external_name: 'Farm Rd Pediatrics', department: 'HFMC'},
      {name: 'FORD RD WOMEN\'S HEALTH', id: 1010200002, external_name: "Ford Rd Women's Health", department: 'HFMC'},
      {name: 'FORD RD PEDIATRICS', id: 1010200006, external_name: 'Ford Rd Pediatrics', department: 'HFMC'},
      {name: 'NCO WOMEN\'S HEALTH', id: 1010270011, external_name: "NCO Women's Health", department: 'HFMC'},
      {name: 'NCO PEDIATRICS', id: 1010270012, external_name: 'NCO Pediatrics', department: 'HFMC'},
      {name: 'ST HGTS PEDIATRICS', id: 1010320012, external_name: 'St Hgts Pediatrics', department: 'HFMC'},
      {name: 'TAYLOR PEDIATRICS', id:  1010350014, external_name: 'Taylor Pediatrics', department: 'HFMC'},
      {name: 'BLOOM TWP PEDIATRICS', id: 1011220001, external_name: 'Bloomfield Twp Pediatrics', department: ''},
      {name: 'BLOOM TWP FAMILY MEDICINE', id: 1011220023, external_name: 'Bloomfield Twp Family Medicine', department: 'HFMC'},
      {name: 'ROY OAK PEDIATRICS', id: 1011410027, external_name: 'Royal Oak Pediatrics', department: 'HFMC'},
      {name: 'DETROIT NW WOMEN\'S HEALTH', id: 1010150007, external_name: "Detroit NW Women's Health", department: 'HFMC'},
      {name: 'WB CLINIC WOMEN\'S HEALTH', id: 1040030014, external_name: "WBH Women's Health", department: 'HFMC'},
      {name: 'BLOOM TWP WOMEN\'S HEALTH', id: 1011220010, external_name: "Bloomfield Twp Women's Health", department: ''},
      {name: 'ROY OAK WOMEN\'S HEALTH', id: 1011410003, external_name: "Royal Oak Women's Health", department: 'HFMC'},
      {name: 'ROYAL OAK WOMEN\'S HEALTH', id: 1010310003, external_name: "Royal Oak Women's Health", department: 'HFMC'},
      {name: 'COMMERCE FAMILY MEDICINE', id: 1010130002, external_name: 'Commerce Family Medicine', department: ''},
      {name: 'BECK RD PEDIATRICS', id: 1010300007, external_name: 'Beck Rd Pediatrics', department: 'HFMC'},
      {name: 'LIVONIA PEDIATRICS', id: 1010240009, external_name: 'Livonia Pediatrics', department: 'HFMC'},
      {name: 'HARBORTOWN PEDIATRICS', id: 1010220011, external_name: 'Harbortown Pediatrics', department: 'HFMC'},
      {name: 'LAKESIDE PEDIATRICS', id: 1010230015, external_name: 'Lakeside Pediatrics', department: 'HFMC'},
      {name: 'MACOMB OB GYN', id: 1060280001, external_name: 'Macomb OB GYN', department: 'HFMC'},
      {name: 'PARTRIDGE CREEK OB GYN', id: 1060310001, external_name: 'Partridge Creek OB GYN', department: 'HFMC'},
      {name: 'CHESTERFIELD OB GYN', id: 1060040015, external_name: 'Chesterfield OB GYN', department: 'HFMC'},
      {name: 'WARREN EAST GYNECOLOGY', id: 1060260002, external_name: 'Warren East Gynecology', department: 'HFMC'},
      {name: 'FRASER OB GYN', id: 1060050005, external_name: 'Fraser OB GYN', department: 'HFMC'},
      {name: 'MOP LAKESIDE OB GYN', id: 1060170001, external_name: 'MOP Lakeside OB GYN', department: 'HFM'},
      {name: 'MOP LAKESIDE OB GYN RESIDENT CLINIC', id: 1060170003, external_name: 'MOP Lakeside OBGYN Resident Clinic', department: 'HFM'},
      {name: 'JACKSON WOMEN\'S HEALTH', id: 1120330002, external_name: "Henry Ford Allegiance Women's Health", department: ''}
    ]

    p 'dropping MILFORD WOMEN\'S HEALTH location...'
    ClinicLocation.find_by(name: 'MILFORD WOMEN\'S HEALTH'.downcase, external_id: 1010880007)&.destroy

    p 'Adding external name to clinic locations...'

    locations.each do |location|
      ClinicLocation.find_by(name: location[:name].downcase, department: 'HFMC').update!(external_name: location[:external_name].downcase, department: location[:department])
    end
  end
end
