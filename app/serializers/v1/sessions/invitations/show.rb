# frozen_string_literal: true

class V1::Sessions::Invitations::Show < BaseSerializer
  def cache_key
    "sessions/invitation/#{@session_invitation.id}-#{@session_invitation.updated_at&.to_s(:number)}"
  end

  def to_json
    {
      id: @session_invitation.id,
      session_id: @session_invitation.session_id,
      email: @session_invitation.email
    }
  end
end
