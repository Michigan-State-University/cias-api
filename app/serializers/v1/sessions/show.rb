# frozen_string_literal: true

class V1::Sessions::Show < BaseSerializer
  def cache_key
    "session/#{session.id}-#{session.updated_at&.to_s(:number)}"
  end

  def to_json
    {
      id: session.id,
      problem_id: session.problem.id,
      settings: session.settings,
      position: session.position,
      name: session.name,
      slug: session.slug,
      schedule: session.schedule,
      schedule_at: session.schedule_at,
      formula: session.formula,
      body: session.body,
      created_at: session.created_at,
      updated_at: session.updated_at
    }
  end

  private

  attr_reader :session
end
