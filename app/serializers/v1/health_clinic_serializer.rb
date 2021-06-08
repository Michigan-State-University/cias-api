# frozen_string_literal: true

class V1::HealthClinicSerializer < V1Serializer
  attributes :name, :health_system_id

  attribute :health_clinic_admins do |object|
    user_ids = object.user_health_clinics.select(:user_id)
    User.where(id: user_ids)
  end
end
