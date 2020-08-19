# frozen_string_literal: true

class Clone::Problem < Clone::Base
  def execute
    create_interventions
    outcome
  end

  private

  def create_interventions
    source.interventions.each do |intervention|
      Clone::Intervention.new(intervention, problem_id: outcome.id).execute
    end
  end
end
