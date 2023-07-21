# frozen_string_literal: true

namespace :one_time_use do
  desc 'Injection into the database of all sites available to CIAS. The location is needed to properly configure the intervention with HFHS integration enabled.'
  task dump_clinic_locations: :environment do
    p 'Creating locations...'

    department = 'HFMC'
    locations = ['DETC INFECTIOUS DISEASE', 'FARM RD PEDIATRICS', 'FORD RD WOMENS HEALTH', 'FORD RD PEDIATRICS', 'NCO WOMENS HEALTH', 'NCO PEDIATRICS','ST HGTS PEDIATRICS', 'TAYLOR PEDIATRICS', 'BLOOM TWP PEDIATRICS','BLOOM TWP FAMILY MEDICINE', 'ROY OAK PEDIATRICS', 'DETROIT NW WOMENS HEALTH', 'WB CLINIC WOMENS HEALTH', 'BLOOM TWP WOMENS HEALTH', 'MILFORD WOMENS HEALTH', 'ROY OAK WOMENS HEALTH', 'ROYAL OAK WOMENS HEALTH', 'COMMERCE FAMILY MEDICINE', 'BECK RD PEDIATRICS', 'LIVONIA PEDIATRICS', 'HARBORTOWN PEDIATRICS', 'LAKESIDE PEDIATRICS', 'MACOMB OB GYN', 'PARTRIDGE CREEK OB GYN', 'CHESTERFIELD OB GYN', 'WARREN EAST GYNECOLOGY', 'FRASER OB GYN', 'MOP LAKESIDE OB GYN', 'MOP LAKESIDE OB GYN RESIDENT CLINIC', 'JACKSON WOMENS HEALTH']

    locations.each { |location| ClinicLocation.create!(name: location.downcase, department: department) }

    p 'DONE!'
  end
end
