# frozen_string_literal: true

class V1::HealthClinicInvitationSerializer < V1Serializer
  attributes :user_id, :health_clinic_id

  attribute :is_accepted, &:accepted_at?
end
