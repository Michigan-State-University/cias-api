# frozen_string_literal: true

class V1::Interventions::Invitations::Index < BaseSerializer
  def cache_key
    "interventions/invitations/#{@inter_invitations.count}-#{@inter_invitations.maximum(:updated_at)&.to_s(:number)}"
  end

  def to_json
    { intervention_invitations: collect_inter_invitations }
  end

  private

  def collect_inter_invitations
    @inter_invitations.map do |inter_invitation|
      V1::Interventions::Invitations::Show.new(inter_invitation: inter_invitation).to_json
    end
  end
end
