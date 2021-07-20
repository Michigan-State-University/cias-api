# frozen_string_literal: true

class V1::OrganizableInvitationSerializer < V1Serializer
  attributes :user_id

  attribute :is_accepted, &:accepted_at?

  attribute :organizable_id do |object|
    if object.instance_of?(OrganizationInvitation)
      object.organization_id
    elsif object.instance_of?(HealthSystemInvitation)
      object.health_system_id
    elsif object.instance_of?(HealthClinicInvitation)
      object.health_clinic_id
    end
  end
end
