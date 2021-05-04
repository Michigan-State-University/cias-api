# frozen_string_literal: true

class V1::OrganizationSerializer < V1Serializer
  attributes :name

  attribute :health_systems_and_clinics do |object|
    V1::HealthSystemSerializer.new(object.health_systems)
  end

  has_many :e_intervention_admins, serializer: V1::UserSerializer
  has_many :organization_admins, serializer: V1::UserSerializer
end
