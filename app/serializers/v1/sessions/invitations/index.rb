# frozen_string_literal: true

class V1::Sessions::Invitations::Index < BaseSerializer
  def cache_key
    "sessions/invitations/#{@invitations.count}-#{@invitations.maximum(:updated_at)&.to_s(:number)}"
  end

  def to_json
    { invitations: collect_session_invitations }
  end

  private

  def collect_session_invitations
    @invitations.map do |invitation|
      V1::Sessions::Invitations::Show.new(invitation: invitation).to_json
    end
  end
end
