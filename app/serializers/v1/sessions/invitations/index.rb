# frozen_string_literal: true

class V1::Sessions::Invitations::Index < BaseSerializer
  def cache_key
    "sessions/invitations/#{@session_invitations.count}-#{@session_invitations.maximum(:updated_at)&.to_s(:number)}"
  end

  def to_json
    { session_invitations: collect_session_invitations }
  end

  private

  def collect_session_invitations
    @session_invitations.map do |session_invitation|
      V1::Sessions::Invitations::Show.new(session_invitation: session_invitation).to_json
    end
  end
end
