# frozen_string_literal: true

class V1::Interventions::Show < BaseSerializer
  def cache_key
    "intervention/#{@intervention.id}-#{@intervention.updated_at&.to_s(:number)}"
  end

  def to_json
    {
      id: @intervention.id,
      name: @intervention.name,
      status: @intervention.status,
      shared_to: @intervention.shared_to,
      created_at: @intervention.created_at,
      updated_at: @intervention.updated_at,
      published_at: @intervention.published_at,
      user: {
        email: @intervention.user.email,
        first_name: @intervention.user.first_name,
        last_name: @intervention.user.last_name
      },
      sessions_size: @intervention.sessions.size
    }
  end
end
