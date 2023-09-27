# frozen_string_literal: true

namespace :one_time_use do
  desc 'Assign to our locations, used during integration with HFHS, external IDs'
  task assign_external_id_to_clinic_location: :environment do
    begin
      ClinicLocation.reset_column_information
      rescue StandardError
        nil
    end

    locations = [
      {name: 'DETC INFECTIOUS DISEASE', id: 1010010049},
      {name: 'FARM RD PEDIATRICS', id: 1010190005},
      {name: 'FORD RD WOMEN\'S HEALTH', id: 1010200002},
      {name: 'FORD RD PEDIATRICS', id: 1010200006},
      {name: 'NCO WOMEN\'S HEALTH', id: 1010270011},
      {name: 'NCO PEDIATRICS', id: 1010270012},
      {name: 'ST HGTS PEDIATRICS', id: 1010320012},
      {name: 'TAYLOR PEDIATRICS', id:  1010350014},
      {name: 'BLOOM TWP PEDIATRICS', id: 1011220001},
      {name: 'BLOOM TWP FAMILY MEDICINE', id: 1011220023},
      {name: 'ROY OAK PEDIATRICS', id: 1011410027},
      {name: 'DETROIT NW WOMEN\'S HEALTH', id: 1010150007},
      {name: 'WB CLINIC WOMEN\'S HEALTH', id: 1040030014},
      {name: 'BLOOM TWP WOMEN\'S HEALTH', id: 1011220010},
      {name: 'MILFORD WOMEN\'S HEALTH', id: 1010880007},
      {name: 'ROY OAK WOMEN\'S HEALTH', id: 1011410003},
      {name: 'ROYAL OAK WOMEN\'S HEALTH', id: 1010310003},
      {name: 'COMMERCE FAMILY MEDICINE', id: 1010130002},
      {name: 'BECK RD PEDIATRICS', id: 1010300007},
      {name: 'LIVONIA PEDIATRICS', id: 1010240009},
      {name: 'HARBORTOWN PEDIATRICS', id: 1010220011},
      {name: 'LAKESIDE PEDIATRICS', id: 1010230015},
      {name: 'MACOMB OB GYN', id: 1060280001},
      {name: 'PARTRIDGE CREEK OB GYN', id: 1060310001},
      {name: 'CHESTERFIELD OB GYN', id: 1060040015},
      {name: 'WARREN EAST GYNECOLOGY', id: 1060260002},
      {name: 'FRASER OB GYN', id: 1060050005},
      {name: 'MOP LAKESIDE OB GYN', id: 1060170001},
      {name: 'MOP LAKESIDE OB GYN RESIDENT CLINIC', id: 1060170003},
      {name: 'JACKSON WOMEN\'S HEALTH', id: 1120330002}
    ]

    p 'Searching and updating locations by external id...'

    locations.each do |location|
      ClinicLocation.find_or_initialize_by(name: location[:name].downcase, department: 'HFMC').update!(external_id: location[:id])
    end

    p 'DONE!'
  end
end
