# frozen_string_literal: true

class V1::Interventions::Show < BaseSerializer
  def cache_key
    "intervention/#{@intervention.id}-#{@intervention.updated_at&.to_s(:number)}"
  end

  def to_json
    {
      id: @intervention.id,
      problem_id: @intervention.problem.id,
      settings: @intervention.settings,
      position: @intervention.position,
      name: @intervention.name,
      slug: @intervention.slug,
      schedule: @intervention.schedule,
      schedule_at: @intervention.schedule_at,
      formula: @intervention.formula,
      body: @intervention.body,
      created_at: @intervention.created_at,
      updated_at: @intervention.updated_at
    }
  end
end
