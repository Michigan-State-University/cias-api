# frozen_string_literal: true

class V1::Interventions::Invitations::Show < BaseSerializer
  def cache_key
    "interventions/invitation/#{@inter_invitation.id}-#{@inter_invitation.updated_at&.to_s(:number)}"
  end

  def to_json
    {
      id: @inter_invitation.id,
      intervention_id: @inter_invitation.intervention_id,
      email: @inter_invitation.email
    }
  end
end
