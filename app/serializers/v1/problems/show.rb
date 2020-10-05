# frozen_string_literal: true

class V1::Problems::Show < BaseSerializer
  def cache_key
    "problem/#{@problem.id}-#{@problem.updated_at}"
  end

  def to_json
    {
      id: @problem.id,
      name: @problem.name,
      status: @problem.status,
      shared_to: @problem.shared_to,
      created_at: @problem.created_at,
      updated_at: @problem.updated_at,
      user: {
        email: @problem.user.email,
        first_name: @problem.user.first_name,
        last_name: @problem.user.last_name
      },
      interventions: collect_interventions
    }
  end

  private

  def collect_interventions
    @problem.interventions.map { |intervention| V1::Interventions::Show.new(intervention: intervention).to_json }
  end
end
