# frozen_string_literal: true

namespace :one_time_use do
  desc 'Injection into the database of all sites available to CIAS. The location is needed to properly configure the intervention with HFHS integration enabled.'
  task dump_clinic_locations: :environment do
    p 'Creating locations...'

    department = 'HFMC'
    locations = ['DETC INFECTIOUS DISEASE', 'FARM RD PEDIATRICS', 'FORD RD WOMEN\'S HEALTH', 'FORD RD PEDIATRICS', 'NCO WOMEN\'S HEALTH', 'NCO PEDIATRICS','ST HGTS PEDIATRICS', 'TAYLOR PEDIATRICS', 'BLOOM TWP PEDIATRICS','BLOOM TWP FAMILY MEDICINE', 'ROY OAK PEDIATRICS', 'DETROIT NW WOMEN\'S HEALTH', 'WB CLINIC WOMEN\'S HEALTH', 'BLOOM TWP WOMEN\'S HEALTH', 'MILFORD WOMEN\'S HEALTH', 'ROY OAK WOMEN\'S HEALTH', 'ROYAL OAK WOMEN\'S HEALTH', 'COMMERCE FAMILY MEDICINE', 'BECK RD PEDIATRICS', 'LIVONIA PEDIATRICS', 'HARBORTOWN PEDIATRICS', 'LAKESIDE PEDIATRICS', 'MACOMB OB GYN', 'PARTRIDGE CREEK OB GYN', 'CHESTERFIELD OB GYN', 'WARREN EAST GYNECOLOGY', 'FRASER OB GYN', 'MOP LAKESIDE OB GYN', 'MOP LAKESIDE OB GYN RESIDENT CLINIC', 'JACKSON WOMEN\'S HEALTH']

    locations.each { |location| ClinicLocation.create!(name: location.downcase, department: department) }

    p 'DONE!'
  end
end
