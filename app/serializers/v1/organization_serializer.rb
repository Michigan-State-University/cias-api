# frozen_string_literal: true

class V1::OrganizationSerializer < V1Serializer
  attributes :name

  has_many :health_clinics, serializer: V1::HealthClinicSerializer
  has_many :health_systems, serializer: V1::HealthSystemSerializer
  has_many :e_intervention_admins, record_type: :user, serializer: V1::UserSerializer
  has_many :organization_admins, record_type: :user, serializer: V1::UserSerializer
  has_many :organization_invitations, serializer: V1::OrganizationInvitationSerializer
end
