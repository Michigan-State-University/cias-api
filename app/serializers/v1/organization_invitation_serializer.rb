# frozen_string_literal: true

class V1::OrganizationInvitationSerializer < V1Serializer
  attributes :user_id, :organization_id

  attribute :is_accepted, &:accepted_at?
end
