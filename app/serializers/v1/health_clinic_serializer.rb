# frozen_string_literal: true

class V1::HealthClinicSerializer < V1Serializer
  attributes :name, :health_system_id

  attribute :deleted, &:deleted?

  has_many :health_clinic_admins, record_type: :user, serializer: V1::UserSerializer
  has_many :health_clinic_invitations, serializer: V1::OrganizableInvitationSerializer
end
