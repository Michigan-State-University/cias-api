# frozen_string_literal: true

class V1::HfhsPatientDetailSerializer < V1Serializer
  attributes :patient_id

  attribute :zip_code, &:provided_zip

  %i[first_name last_name dob sex phone_number phone_type].each do |attr|
    attribute attr do |object|
      object.send(:"provided_#{attr}")
    end
  end
end
