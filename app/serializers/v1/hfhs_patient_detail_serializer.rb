# frozen_string_literal: true

class V1::HfhsPatientDetailSerializer < V1Serializer
  attributes :patient_id, :first_name, :last_name, :dob, :sex, :zip_code
end
