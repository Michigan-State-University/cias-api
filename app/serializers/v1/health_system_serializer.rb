# frozen_string_literal: true

class V1::HealthSystemSerializer < V1Serializer
  attributes :name, :organization_id

  attribute :deleted, &:deleted?

  has_many :health_clinics, serializer: V1::HealthClinicSerializer
  has_many :health_system_admins, record_type: :user, serializer: V1::UserSerializer
end
