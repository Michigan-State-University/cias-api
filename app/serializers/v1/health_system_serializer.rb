# frozen_string_literal: true

class V1::HealthSystemSerializer < V1Serializer
  attributes :name, :organization_id

  attribute :health_clinics do |object|
    V1::HealthClinicSerializer.new(object.health_clinics)
  end

  has_many :health_system_admins, serializer: V1::UserSerializer
end
