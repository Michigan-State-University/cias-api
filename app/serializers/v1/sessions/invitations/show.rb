# frozen_string_literal: true

class V1::Sessions::Invitations::Show < BaseSerializer
  def cache_key
    "sessions/invitation/#{@invitation.id}-#{@invitation.updated_at&.to_s(:number)}"
  end

  def to_json
    {
      id: @invitation.id,
      invitable_id: @invitation.invitable_id,
      email: @invitation.email
    }
  end
end
