# frozen_string_literal: true

FactoryBot.define do
  factory :hfhs_patient_detail do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    dob { Faker::Date.birthday(min_age: 18, max_age: 65) }
    sex { 'M' }
    visit_id { 'AttendingProvider_EpicDepartmentID_VisitNumber' }
    zip_code { Faker::Address.zip }
    patient_id { '89008709' }
  end
end
